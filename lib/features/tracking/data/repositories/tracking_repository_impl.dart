import 'dart:async';

import 'package:camera/camera.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/filters/landmark_stabilizer.dart';
import '../../../../core/isolate/detection_isolate.dart';
import '../../../../core/isolate/detection_runner.dart';
import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../domain/entities/anchor_pose.dart';
import '../../domain/entities/tracking_frame.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../domain/strategies/tracking_strategy.dart';

/// Pipeline de tracking en tiempo real:
/// cámara → [DetectionIsolate] → estrategia de anclaje → estabilizador →
/// [TrackingFrame].
///
/// - El **detector** (manos, rostro o pose, según la plataforma) vive dentro
///   de un isolate dedicado (spike B5): la detección es costosa (15–40 ms de
///   trabajo nativo por frame) y correrla en el isolate principal saturaba la
///   UI hasta el punto de producir ANR al cambiar de categoría.
/// - La **cámara** usa la lente trasera para pulseras (el usuario apunta a su
///   muñeca) y la frontal para aretes y collares.
/// - La detección se limita con throttling (≤10 FPS) para no encolar más
///   peticiones de las que el isolate puede procesar.
/// - Se estabilizan posición, orientación y escala por separado; el ángulo con
///   un filtro que no salta al cruzar ±π.
class TrackingRepositoryImpl implements TrackingRepository {
  final CameraService cameraService;
  final Map<JewelryCategory, TrackingStrategy> strategies;
  final LandmarkStabilizer stabilizer;

  /// Intervalo mínimo entre detecciones, por tipo de detector.
  ///
  /// Manos: desde el plugin 3.x entregar el frame no bloquea y los resultados
  /// llegan por su propio stream, así que este intervalo ya no protege de
  /// nada: se convierte en latencia añadida (sondear a 10 Hz añadía hasta
  /// 100 ms). Se sondea al ritmo de la cámara.
  ///
  /// Rostro y pose (ML Kit): ahí `detect()` sí hace el trabajo pesado y el
  /// guardia `_busy` ya impide encolar; se mantiene el techo de 10 FPS con el
  /// que se validaron aretes y collares.
  static int _minIntervalMsFor(DetectorKind kind) =>
      kind == DetectorKind.hand ? 33 : 100;

  /// Frecuencia de detección de referencia para dimensionar el margen de
  /// pérdida de tracking.
  ///
  /// Medido en dispositivo (Galaxy A15, compilación de depuración) con el
  /// plugin 3.x: 8–10 Hz, frente a los 3.5 Hz del plugin 2.x, que comprimía
  /// cada frame a JPEG y lo volvía a decodificar. Oscila porque en modo
  /// `LIVE_STREAM` MediaPipe solo re-ejecuta la detección de palma cuando
  /// pierde el seguimiento; mientras trackea, el frame sale mucho más barato.
  ///
  /// No se usa para afinar los filtros: el corte del One Euro va en Hz, así
  /// que su retardo en segundos no depende de la frecuencia de muestreo.
  static const double _detectionHz = 9.0;

  /// Margen antes de declarar perdido el tracking. Sin él, un solo frame sin
  /// detección (frecuentes con MediaPipe) haría parpadear la joya.
  ///
  /// Se expresa en detecciones fallidas, no en milisegundos, para que siga
  /// teniendo sentido si cambia [_detectionHz]. Con el margen fijo anterior
  /// (400 ms, algo más de una detección) bastaba un único hueco para que la
  /// joya desapareciera y volviera: ese era el parpadeo al acercar la mano.
  static const double _lostGraceDetections = 3;

  static final int _lostGraceMs =
      (_lostGraceDetections * 1000 / _detectionHz).round();

  StreamController<TrackingFrame>? _controller;
  DetectionRunner? _activeRunner;
  JewelryCategory? _activeCategory;
  bool _busy = false;
  int _lastMs = 0;
  int _lastDetectionMs = 0;
  bool _lost = true;

  TrackingRepositoryImpl({
    required this.cameraService,
    required this.strategies,
    LandmarkStabilizer? stabilizer,
  }) : stabilizer = stabilizer ?? OneEuroStabilizer();

  LandmarkStabilizer _stabilizerFor(JewelryCategory category) =>
      switch (category) {
        // Aretes: más suavizado — el bbox/landmarks faciales tiemblan más
        // que pose. Afinado y validado antes; se deja como estaba.
        JewelryCategory.earring =>
          OneEuroStabilizer(minCutoff: 0.4, beta: 0.007, dCutoff: 1.0),
        // Pulseras: el `beta` es lo que abre el filtro cuando la mano se
        // mueve. En coordenadas normalizadas las velocidades son del orden
        // de 1 por segundo, así que con beta = 0.02 el término de velocidad
        // subía el corte en 0.02 Hz: inapreciable, y el One Euro se
        // comportaba como un pasa-bajos fijo con todo su retardo. Con beta = 1
        // el corte se duplica al mover la muñeca y el retardo cae a la mitad,
        // sin perder el suavizado en reposo.
        //
        // El corte va en Hz, así que su retardo no depende de la frecuencia
        // de muestreo: con minCutoff = 1 son ~160 ms corra a 3.5 o a 9 Hz. Al
        // subir la detección con el plugin 3.x ese retardo pasó a ser la
        // mitad del total, y con el triple de muestras se puede abrir el
        // filtro sin pagarlo en temblor: con 2.0 baja a ~80 ms en reposo.
        JewelryCategory.bracelet =>
          OneEuroStabilizer(minCutoff: 2.0, beta: 1.0),
        _ => stabilizer,
      };

  LandmarkStabilizer? _sessionStabilizer;
  AngleStabilizer? _rollStabilizer;
  ScalarStabilizer? _scaleStabilizer;

  @override
  Stream<TrackingFrame> trackingStream(JewelryCategory category) {
    final strategy = strategies[category];
    if (strategy == null) {
      return const Stream<TrackingFrame>.empty();
    }

    final controller = StreamController<TrackingFrame>();

    controller.onListen = () async {
      try {
        await stop(); // asegura que no quede una sesión previa a medio liberar
        _controller = controller;
        _activeCategory = category;
        strategy.reset();
        _sessionStabilizer = _stabilizerFor(category);
        // Roll y escala se filtran con el mismo criterio que la posición.
        // El afinado anterior (minCutoff 0.3) partía de suponer ~10 Hz de
        // detección; a los 3.5 Hz reales daba medio segundo de retardo y en
        // dispositivo el tamaño de la pieza no llegaba a cambiar a la vista.
        _rollStabilizer = AngleStabilizer(minCutoff: 1.5, beta: 0.5);
        _scaleStabilizer = ScalarStabilizer(minCutoff: 1.5, beta: 0.5);
        _lost = true;
        _lastDetectionMs = 0;
        final runner = _runnerFor(strategy.detectorKind);
        _activeRunner = runner;
        await runner.start(strategy.detectorKind);
        await cameraService.startStream(
          (frame) => _onFrame(frame, strategy, runner),
          lensDirection: _lensFor(category),
          imageFormatGroup: imageFormatGroupFor(strategy.detectorKind),
        );
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    };
    controller.onCancel = stop;
    return controller.stream;
  }

  Future<void> _onFrame(
    CameraImage frame,
    TrackingStrategy strategy,
    DetectionRunner runner,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_busy || now - _lastMs < _minIntervalMsFor(strategy.detectorKind)) {
      return;
    }
    _busy = true;
    _lastMs = now;
    try {
      final orientation =
          cameraService.controller?.description.sensorOrientation ?? 0;
      final landmarks = await runner.detect(frame, orientation);
      final anchor = strategy.computeAnchor(
        landmarks,
        imageAspect: uprightAspect(frame, orientation),
      );
      final controller = _controller;
      if (controller == null || controller.isClosed) return;

      if (anchor == null) {
        // Se espera el margen de gracia antes de avisar de la pérdida, y se
        // avisa una sola vez para no inundar la UI de reconstrucciones.
        if (!_lost && now - _lastDetectionMs > _lostGraceMs) {
          _lost = true;
          _resetFilters();
          controller.add(const TrackingFrame.lost());
        }
        return;
      }

      _lost = false;
      _lastDetectionMs = now;
      controller.add(TrackingFrame(
        anchor: _smooth(anchor, now / 1000.0),
        landmarks: landmarks,
      ));
    } catch (_) {
      // Se descarta el frame con error para no interrumpir el stream.
    } finally {
      _busy = false;
    }
  }

  AnchorPose _smooth(AnchorPose anchor, double tSeconds) {
    final position =
        (_sessionStabilizer ?? stabilizer).filter(anchor.position, tSeconds);
    final scale = anchor.scale;
    return AnchorPose(
      position: position,
      rollRadians:
          _rollStabilizer?.filter(anchor.rollRadians, tSeconds) ??
              anchor.rollRadians,
      scale: scale == null ? null : _scaleStabilizer?.filter(scale, tSeconds),
      confidence: anchor.confidence,
    );
  }

  /// Al recuperar el tracking la mano suele reaparecer en otro sitio; arrancar
  /// los filtros de cero evita que la joya cruce la pantalla deslizándose.
  void _resetFilters() {
    _sessionStabilizer?.reset();
    _rollStabilizer?.reset();
    _scaleStabilizer?.reset();
  }

  /// Relación ancho/alto del frame **ya rotado a vertical**, que es el marco en
  /// el que MediaPipe normaliza los landmarks cuando se le pasa la rotación
  /// del sensor. Con el sensor a 90°/270° los ejes del buffer están
  /// intercambiados respecto a lo que se ve en pantalla.
  static double uprightAspect(CameraImage frame, int sensorOrientation) {
    if (frame.width <= 0 || frame.height <= 0) return 1.0;
    final rotation = ((sensorOrientation % 360) + 360) % 360;
    final swapped = rotation == 90 || rotation == 270;
    final width = swapped ? frame.height : frame.width;
    final height = swapped ? frame.width : frame.height;
    return width / height;
  }

  /// La detección de manos en Android tiene que correr en el isolate raíz:
  /// su plugin publica los resultados por un `EventChannel`, y Flutter no
  /// permite recibir mensajes del host en un isolate secundario. Ya no bloquea,
  /// así que tampoco necesita aislamiento. El resto sigue en el isolate
  /// dedicado del spike B5.
  DetectionRunner _runnerFor(DetectorKind kind) =>
      requiresRootIsolate(kind) ? InlineDetectionRunner() : DetectionIsolate();

  CameraLensDirection _lensFor(JewelryCategory category) =>
      category == JewelryCategory.bracelet
          ? CameraLensDirection.back
          : CameraLensDirection.front;

  @override
  Future<void> stop() async {
    await cameraService.dispose();
    await _activeRunner?.dispose();
    _activeRunner = null;
    strategies[_activeCategory]?.reset();
    _activeCategory = null;
    _resetFilters();
    _sessionStabilizer = null;
    _rollStabilizer = null;
    _scaleStabilizer = null;
    stabilizer.reset();
    _lost = true;
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }
}

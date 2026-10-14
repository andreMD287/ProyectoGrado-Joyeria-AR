// Spike B9 — ¿ve ML Kit Pose el antebrazo con solo un brazo en el encuadre?
//
// El anclaje de pulseras estima la direccion del antebrazo **prolongando el
// eje de la mano**, porque MediaPipe Hands no ve mas alla de la muñeca. Eso
// falla cuando la muñeca esta doblada: medido sobre captura con el overlay de
// diagnostico, el eje estimado apuntaba 95 grados (casi recto hacia abajo)
// mientras el antebrazo real bajaba hacia la derecha. Ese error angular
// descentra el ancla y hace que la pieza no cierre sobre el brazo.
//
// `google_mlkit_pose_detection` ya es dependencia del proyecto (collares) y
// entrega muñeca y codo, con lo que el eje dejaria de adivinarse. La duda es
// si detecta algo: esta entrenado para cuerpos completos y aqui solo hay un
// brazo visto por la camara trasera. Es la misma pregunta que hundio a la
// segmentacion, asi que se comprueba igual: pintando lo que detecte.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SpikePage(),
      );
}

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});

  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  CameraController? camera;
  final _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  Pose? _pose;
  Size _imagen = Size.zero;
  String estado = 'iniciando...';
  int _sensorOrientation = 0;

  bool _ocupado = false;
  int _frames = 0;
  DateTime _desde = DateTime.now();
  double hz = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final camaras = await availableCameras();
    if (camaras.isEmpty) {
      setState(() => estado = 'sin camaras');
      return;
    }
    final trasera = camaras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => camaras.first,
    );
    _sensorOrientation = trasera.sensorOrientation;

    final controller = CameraController(
      trasera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await controller.initialize();
    if (!mounted) return;

    await controller.startImageStream(_onFrame);
    setState(() {
      camera = controller;
      estado = 'camara lista';
    });
  }

  Future<void> _onFrame(CameraImage frame) async {
    if (_ocupado) return;
    _ocupado = true;
    try {
      final input = _toInputImage(frame);
      if (input == null) return;

      final poses = await _detector.processImage(input);

      _frames++;
      final ms = DateTime.now().difference(_desde).inMilliseconds;
      if (ms >= 1000) {
        hz = _frames * 1000 / ms;
        _frames = 0;
        _desde = DateTime.now();
      }

      if (!mounted) return;
      setState(() {
        // Los landmarks vienen en pixeles del frame **ya rotado**, asi que con
        // el sensor a 90 grados los ejes estan intercambiados.
        _imagen = _sensorOrientation == 90 || _sensorOrientation == 270
            ? Size(frame.height.toDouble(), frame.width.toDouble())
            : Size(frame.width.toDouble(), frame.height.toDouble());

        if (poses.isEmpty) {
          _pose = null;
          estado = 'SIN POSE · ${hz.toStringAsFixed(1)} Hz';
        } else {
          _pose = poses.first;
          final m = poses.first.landmarks;
          String v(PoseLandmarkType t) {
            final l = m[t];
            return l == null ? '-' : l.likelihood.toStringAsFixed(2);
          }

          estado = 'pose: ${m.length} pts · ${hz.toStringAsFixed(1)} Hz\n'
              'muñeca izq ${v(PoseLandmarkType.leftWrist)} · '
              'codo izq ${v(PoseLandmarkType.leftElbow)}\n'
              'muñeca der ${v(PoseLandmarkType.rightWrist)} · '
              'codo der ${v(PoseLandmarkType.rightElbow)}';
        }
      });
    } catch (e) {
      if (mounted) setState(() => estado = 'error: $e');
    } finally {
      _ocupado = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final rotation =
        InputImageRotationValue.fromRawValue(_sensorOrientation) ??
            InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    camera?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = camera;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.previewSize!.height,
                height: controller.value.previewSize!.width,
                child: CameraPreview(controller),
              ),
            ),

          if (_pose != null && _imagen != Size.zero)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _PosePainter(_pose!, _imagen)),
              ),
            ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: Colors.black87,
                child: Text(
                  estado,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinta lo detectado. Muñeca y codo van resaltados y unidos por una linea,
/// porque ese segmento **es** el eje del antebrazo que se busca.
class _PosePainter extends CustomPainter {
  final Pose pose;
  final Size imagen;

  const _PosePainter(this.pose, this.imagen);

  @override
  void paint(Canvas canvas, Size size) {
    // El preview se dibuja con `cover`: misma escala en ambos ejes y recorte.
    final escala = size.width / imagen.width > size.height / imagen.height
        ? size.width / imagen.width
        : size.height / imagen.height;
    final dx = (size.width - imagen.width * escala) / 2;
    final dy = (size.height - imagen.height * escala) / 2;

    Offset? p(PoseLandmarkType t) {
      final l = pose.landmarks[t];
      if (l == null) return null;
      return Offset(l.x * escala + dx, l.y * escala + dy);
    }

    final punto = Paint()..color = const Color(0xCC00E5FF);
    for (final l in pose.landmarks.values) {
      canvas.drawCircle(
        Offset(l.x * escala + dx, l.y * escala + dy),
        6,
        punto,
      );
    }

    final destacado = Paint()..color = const Color(0xFFFF3D00);
    final linea = Paint()
      ..color = const Color(0xFFFF3D00)
      ..strokeWidth = 6;

    for (final (muneca, codo) in [
      (PoseLandmarkType.leftWrist, PoseLandmarkType.leftElbow),
      (PoseLandmarkType.rightWrist, PoseLandmarkType.rightElbow),
    ]) {
      final a = p(muneca);
      final b = p(codo);
      if (a == null || b == null) continue;
      canvas.drawLine(a, b, linea);
      canvas.drawCircle(a, 14, destacado);
      canvas.drawCircle(b, 14, destacado);
    }
  }

  @override
  bool shouldRepaint(covariant _PosePainter oldDelegate) => true;
}

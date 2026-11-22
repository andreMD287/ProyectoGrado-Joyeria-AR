import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../math/geometry.dart';

/// `true` solo si se compila con `--dart-define=METRICS=true`.
///
/// Cada llamada a [TrackingMetrics] va detrás de `if (kMetrics)`. Con la
/// constante en `false`, que es lo normal, el compilador elimina esos bloques
/// enteros: no se mide ni se guarda nada, y no cuesta nada.
const bool kMetrics = bool.fromEnvironment('METRICS');

/// Instrumentación del escenario de calidad EC-03 (SRS RD-02 y RD-07).
///
/// Por cada pose publicada escribe una fila en un CSV del directorio de
/// documentos de la app (`ec03_<categoría>_<fecha>.csv`, uno por sesión de
/// prueba virtual) con:
///
/// - `t_frame`: llegada a Dart del fotograma cuyos landmarks produjeron la
///   pose.
/// - `t_dispatch`: cuando ese fotograma se entregó al detector.
/// - `t_result`: cuando llegaron a Dart sus landmarks.
/// - `t_pose`: cuando se publicó la pose estabilizada.
/// - `t_draw`: fin del primer frame de Flutter que reconstruyó la escena con
///   esa pose (`addPostFrameCallback`). Vacío si llegó otra pose antes de que
///   se dibujara. La textura 3D puede presentarse uno o dos vsync después:
///   eso ya no se ve desde Dart.
/// - El ancla sin filtrar (la que entrega la estrategia) y la filtrada,
///   normalizadas al frame y proyectadas a píxeles lógicos con el mismo
///   [PreviewFit] que usa la escena, más la `devicePixelRatio`.
///
/// Los tiempos son milisegundos de un reloj monotónico propio.
///
/// **Emparejar el fotograma con su resultado** depende del detector (columna
/// `emparejamiento`):
///
/// - `directo`: detectores de petición y respuesta, el resultado vuelve en la
///   misma llamada.
/// - `id`: la cabeza para aretes en Android. Se le pasa al nativo el número de
///   fotograma y lo devuelve con el resultado: exacto aunque descarte
///   fotogramas.
/// - `fifo`: manos en Android. El plugin entrega un resultado por fotograma
///   procesado, en orden pero sin identificarlo. Si MediaPipe descarta uno, el
///   emparejamiento se corre un fotograma: `n_despachos` y `n_resultados`
///   permiten detectarlo.
/// - `ultimo`: el cuello, que responde con el último resultado que tenga. No
///   se puede saber de qué fotograma es, así que no se registran los tiempos
///   del detector.
class TrackingMetrics {
  TrackingMetrics._();

  static final TrackingMetrics instance = TrackingMetrics._();

  final Stopwatch _reloj = Stopwatch()..start();

  /// Milisegundos del reloj del registrador.
  double ahora() => _reloj.elapsedMicroseconds / 1000.0;

  IOSink? _csv;
  int _sesion = 0;
  String _categoria = '';
  String _modoDetector = '';
  String _emparejamiento = '';

  int _ultimoId = 0;
  int _nDespachos = 0;
  int _nResultados = 0;
  int _nPoses = 0;

  _Despacho? _ultimoDespacho;
  final Queue<_Despacho> _fifo = Queue();
  final Map<int, _Despacho> _porId = {};

  /// Número del fotograma que se está entregando, para el detector que se lo
  /// pasa al nativo (`id`).
  int? despachoEnCurso;

  /// Resultado del que salen las poses que se publiquen a continuación.
  _Resultado? _resultado;

  final List<_Pose> _sinDibujar = [];
  PreviewFit? _fit;
  double _dpr = 1;

  /// Protocolo de EC-03: [reposoMs] quieto y luego [movimientoMs] en
  /// movimiento moderado, contados desde que se toca «Iniciar medición» (ver
  /// `Ec03ProtocolOverlay`). Cada fila lleva su fase y `t_prot`, el tiempo
  /// desde ese toque, para que el reporte no dependa de contar de memoria.
  static const double reposoMs = 10000;
  static const double movimientoMs = 20000;

  double? _inicioProtocolo;

  /// Momento en que se tocó «Iniciar medición», o `null` si aún no.
  double? get inicioProtocolo => _inicioProtocolo;

  bool get sesionActiva => _csv != null;

  void iniciarProtocolo() {
    if (_csv == null) return;
    _inicioProtocolo = ahora();
    // ignore: avoid_print
    print('EC03 protocolo iniciado');
  }

  /// Fase del protocolo en el instante [t] del reloj del registrador.
  String fase(double t) {
    final inicio = _inicioProtocolo;
    if (inicio == null || t < inicio) return 'previo';
    final d = t - inicio;
    if (d < reposoMs) return 'reposo';
    if (d < reposoMs + movimientoMs) return 'movimiento';
    return 'posterior';
  }

  /// Abre el CSV de una sesión nueva.
  Future<void> iniciarSesion({
    required String categoria,
    required String modoDetector,
    required String emparejamiento,
  }) async {
    await cerrarSesion();
    _sesion++;
    _categoria = categoria;
    _modoDetector = modoDetector;
    _emparejamiento = emparejamiento;
    _ultimoId = 0;
    _nDespachos = 0;
    _nResultados = 0;
    _nPoses = 0;
    _ultimoDespacho = null;
    _fifo.clear();
    _porId.clear();
    despachoEnCurso = null;
    _resultado = null;
    _sinDibujar.clear();
    _inicioProtocolo = null;

    final dir = _documentos();
    await dir.create(recursive: true);
    final fecha = DateTime.now();
    String dos(int v) => v.toString().padLeft(2, '0');
    final sello = '${fecha.year}${dos(fecha.month)}${dos(fecha.day)}_'
        '${dos(fecha.hour)}${dos(fecha.minute)}${dos(fecha.second)}';
    final archivo = File('${dir.path}/ec03_${categoria}_$sello.csv');
    final csv = archivo.openWrite();
    final compilacion = kReleaseMode
        ? 'release'
        : kProfileMode
            ? 'profile'
            : 'debug';
    csv
      ..writeln('# EC-03 fecha=${fecha.toIso8601String()}')
      ..writeln('# plataforma=${Platform.operatingSystem} '
          '${Platform.operatingSystemVersion.replaceAll(',', ' ')}')
      ..writeln('# compilacion=$compilacion categoria=$categoria '
          'modo_detector=$modoDetector emparejamiento=$emparejamiento')
      ..writeln(_columnas.join(','));
    _csv = csv;
    // ignore: avoid_print
    print('EC03 csv=${archivo.path}');
  }

  /// Un fotograma se entrega al detector.
  void registrarDespacho(double tFrame, double tDispatch) {
    if (_csv == null) return;
    final d = _Despacho(++_ultimoId, tFrame, tDispatch);
    _nDespachos++;
    _ultimoDespacho = d;
    switch (_emparejamiento) {
      case 'fifo':
        _fifo.add(d);
      case 'id':
        _porId[d.id] = d;
        despachoEnCurso = d.id;
    }
  }

  /// Volvió el resultado del último fotograma entregado (`directo`).
  void resultadoDirecto() {
    final d = _ultimoDespacho;
    if (_csv == null || _emparejamiento != 'directo' || d == null) return;
    _nResultados++;
    _resultado = _Resultado(d, ahora(), 0);
  }

  /// Llegó un resultado del plugin de manos (`fifo`).
  void resultadoFifo() {
    if (_csv == null || _emparejamiento != 'fifo') return;
    _nResultados++;
    final d = _fifo.isEmpty ? null : _fifo.removeFirst();
    _resultado = d == null ? null : _Resultado(d, ahora(), _fifo.length);
  }

  /// Llegó el resultado del fotograma [id] (`id`). Los anteriores que sigan
  /// pendientes los descartó el nativo.
  void resultadoConId(int? id) {
    if (_csv == null || _emparejamiento != 'id') return;
    _nResultados++;
    final d = id == null ? null : _porId.remove(id);
    if (id != null) _porId.removeWhere((k, _) => k < id);
    _resultado = d == null ? null : _Resultado(d, ahora(), _porId.length);
  }

  /// Se publicó [pose], la pose filtrada. Las coordenadas van normalizadas al
  /// frame.
  void posePublicada(
    Object pose, {
    required double rawX,
    required double rawY,
    required double filtX,
    required double filtY,
  }) {
    if (_csv == null) return;
    final t = ahora();
    final inicio = _inicioProtocolo;
    _sinDibujar.add(_Pose(
      sesion: _sesion,
      seq: ++_nPoses,
      pose: pose,
      resultado: _resultado,
      tPose: t,
      fase: fase(t),
      tProt: inicio == null ? null : t - inicio,
      nDespachos: _nDespachos,
      nResultados: _nResultados,
      rawX: rawX,
      rawY: rawY,
      filtX: filtX,
      filtY: filtY,
    ));
  }

  /// La escena se reconstruyó con [pose]. Se registra cuando termine de
  /// dibujarse el frame.
  void anclaEnEscena(Object? pose, PreviewFit fit, double dpr) {
    if (_csv == null) return;
    _fit = fit;
    _dpr = dpr;
    if (pose == null) return;
    final i = _sinDibujar.indexWhere((p) => identical(p.pose, pose));
    if (i < 0) return;
    // Las anteriores se reemplazaron antes de llegar a dibujarse.
    for (final p in _sinDibujar.sublist(0, i)) {
      _escribir(p, null);
    }
    final p = _sinDibujar[i];
    _sinDibujar.removeRange(0, i + 1);
    SchedulerBinding.instance.addPostFrameCallback((_) => _escribir(p, ahora()));
  }

  Future<void> cerrarSesion() async {
    final csv = _csv;
    if (csv == null) return;
    for (final p in _sinDibujar) {
      _escribir(p, null);
    }
    _sinDibujar.clear();
    _csv = null;
    await csv.flush();
    await csv.close();
  }

  void _escribir(_Pose p, double? tDraw) {
    final csv = _csv;
    if (csv == null || p.sesion != _sesion) return;
    final fit = _fit;
    final r = p.resultado;
    String n(double? v, [int d = 3]) => v == null ? '' : v.toStringAsFixed(d);
    csv.writeln([
      p.seq,
      r?.despacho.id ?? '',
      _emparejamiento,
      r?.pendientes ?? '',
      p.nDespachos,
      p.nResultados,
      n(r?.despacho.tFrame),
      n(r?.despacho.tDispatch),
      n(r?.tResult),
      n(p.tPose),
      n(tDraw),
      n(p.rawX, 5),
      n(p.rawY, 5),
      n(p.filtX, 5),
      n(p.filtY, 5),
      n(fit?.xOf(p.rawX), 2),
      n(fit?.yOf(p.rawY), 2),
      n(fit?.xOf(p.filtX), 2),
      n(fit?.yOf(p.filtY), 2),
      n(_dpr, 3),
      _categoria,
      Platform.operatingSystem,
      _modoDetector,
      p.fase,
      n(p.tProt),
    ].join(','));
  }

  static const List<String> _columnas = [
    'seq',
    'id_resultado',
    'emparejamiento',
    'pendientes',
    'n_despachos',
    'n_resultados',
    't_frame',
    't_dispatch',
    't_result',
    't_pose',
    't_draw',
    'raw_nx',
    'raw_ny',
    'filt_nx',
    'filt_ny',
    'raw_px',
    'raw_py',
    'filt_px',
    'filt_py',
    'dpr',
    'categoria',
    'plataforma',
    'modo_detector',
    'fase',
    't_prot',
  ];

  /// El mismo directorio que `getApplicationDocumentsDirectory()` de
  /// `path_provider`, sin añadir la dependencia: en Android
  /// `<datos de la app>/app_flutter` y en iOS `<contenedor>/Documents`. El
  /// temporal de Dart cuelga de esa misma raíz en las dos plataformas.
  static Directory _documentos() {
    final raiz = Directory.systemTemp.parent.path;
    return Directory('$raiz/${Platform.isIOS ? 'Documents' : 'app_flutter'}');
  }
}

class _Despacho {
  final int id;
  final double tFrame;
  final double tDispatch;

  const _Despacho(this.id, this.tFrame, this.tDispatch);
}

class _Resultado {
  final _Despacho despacho;
  final double tResult;

  /// Fotogramas entregados que seguían sin resultado cuando llegó este.
  final int pendientes;

  const _Resultado(this.despacho, this.tResult, this.pendientes);
}

class _Pose {
  final int sesion;
  final int seq;
  final Object pose;
  final _Resultado? resultado;
  final double tPose;
  final String fase;
  final double? tProt;
  final int nDespachos;
  final int nResultados;
  final double rawX, rawY, filtX, filtY;

  const _Pose({
    required this.sesion,
    required this.seq,
    required this.pose,
    required this.resultado,
    required this.tPose,
    required this.fase,
    required this.tProt,
    required this.nDespachos,
    required this.nResultados,
    required this.rawX,
    required this.rawY,
    required this.filtX,
    required this.filtY,
  });
}

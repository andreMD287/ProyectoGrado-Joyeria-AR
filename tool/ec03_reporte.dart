// Reporte del escenario de calidad EC-03 (SRS RD-02 y RD-07) a partir de los
// CSV que escribe la app compilada con --dart-define=METRICS=true (ver
// lib/core/metrics/tracking_metrics.dart).
//
// Uso:
//   dart run tool/ec03_reporte.dart [--reposo=10] [--duracion=30] [--margen=0.5]
//       corrida1.csv [corrida2.csv ...]
//
// Cada CSV es una corrida (una sesión de prueba virtual). El tiempo se cuenta
// desde la primera pose publicada: los primeros --reposo segundos son el tramo
// en reposo y el resto, hasta --duracion, el tramo en movimiento. Se descartan
// --margen segundos a cada lado de cada tramo.
//
// No usa dependencias: solo dart:io y dart:math.

import 'dart:io';
import 'dart:math' as math;

void main(List<String> args) {
  var reposo = 10.0, duracion = 30.0, margen = 0.5;
  final archivos = <String>[];
  for (final a in args) {
    if (a.startsWith('--reposo=')) {
      reposo = double.parse(a.split('=')[1]);
    } else if (a.startsWith('--duracion=')) {
      duracion = double.parse(a.split('=')[1]);
    } else if (a.startsWith('--margen=')) {
      margen = double.parse(a.split('=')[1]);
    } else {
      archivos.add(a);
    }
  }
  if (archivos.isEmpty) {
    stderr.writeln('Uso: dart run tool/ec03_reporte.dart [--reposo=10] '
        '[--duracion=30] [--margen=0.5] corrida1.csv [corrida2.csv ...]');
    exit(64);
  }

  final corridas = [
    for (final f in archivos) Corrida.leer(File(f), reposo, duracion, margen),
  ];
  final porCategoria = <String, List<Corrida>>{};
  for (final c in corridas) {
    porCategoria.putIfAbsent('${c.categoria} (${c.plataforma})', () => []).add(c);
  }

  final out = StringBuffer();
  out.writeln('EC-03 — reporte de ${corridas.length} corrida(s)');
  out.writeln('Tramos desde «Iniciar medición» (o desde la primera pose si la '
      'corrida no la usó): reposo ${f1(margen)}–'
      '${f1(reposo - margen)} s, movimiento ${f1(reposo + margen)}–'
      '${f1(duracion - margen)} s.');
  out.writeln('Tiempos en ms; error de anclaje en píxeles lógicos (px) y '
      'físicos (px fís. = px × devicePixelRatio).');
  for (final e in porCategoria.entries) {
    reportarCategoria(out, e.key, e.value);
  }
  out.writeln();
  out.writeln('Lo que NO incluye ninguna cifra de este reporte, porque no se '
      'puede medir por software desde Dart:');
  out.writeln('- la latencia del sensor hasta Dart (exposición, ISP y entrega '
      'del fotograma al stream de la cámara);');
  out.writeln('- la latencia de la pantalla (composición, presentación y '
      'barrido). t_draw es el fin del frame de Flutter que reconstruyó la '
      'escena; la textura 3D puede presentarse uno o dos vsync después.');
  stdout.write(out);
}

void reportarCategoria(StringBuffer out, String nombre, List<Corrida> cs) {
  out.writeln();
  out.writeln('=' * 72);
  out.writeln('Categoría: $nombre — ${cs.length} corrida(s)');
  out.writeln('=' * 72);
  for (final c in cs) {
    out.writeln('- ${c.nombre}: ${c.compilacion}, detector ${c.modoDetector}, '
        'emparejamiento ${c.emparejamiento}, tramos desde ${c.base}, '
        '${c.posesEnVentana} poses en la ventana (${c.filas.length} en total), '
        'velocidad mediana del ancla filtrada: reposo '
        '${f0(c.velocidadMediana(Tramo.reposo))} px/s, movimiento '
        '${f0(c.velocidadMediana(Tramo.movimiento))} px/s.');
    final aviso = c.avisoEmparejamiento();
    if (aviso != null) out.writeln('  ! $aviso');
  }

  out.writeln();
  out.writeln('RD-07 — error de anclaje (distancia filtrada vs. sin filtrar):');
  for (final t in Tramo.values) {
    final px = [for (final c in cs) ...c.errores(t, fisico: false)];
    final fis = [for (final c in cs) ...c.errores(t, fisico: true)];
    out.writeln('  ${t.etiqueta.padRight(11)} n=${px.length.toString().padLeft(4)}'
        '  media ${f1(media(px))} px (${f1(media(fis))} px fís.)'
        '  p95 ${f1(percentil(px, 95))} px (${f1(percentil(fis, 95))})'
        '  máx ${f1(maximo(px))} px (${f1(maximo(fis))})'
        '  ${cumple(percentil(px, 95), 40)} con p95 ≤ 40 px');
  }

  out.writeln();
  out.writeln('RD-02 — tramos de latencia (todas las poses de los dos tramos):');
  final medibles = cs.where((c) => c.detectorMedible).toList();
  final muestreo = [for (final c in cs) ...c.lat((f) => f.tDispatch - f.tFrame)];
  final deteccion = [for (final c in medibles) ...c.detecciones()];
  final aPose = [for (final c in medibles) ...c.lat((f) => f.tPose - f.tResult)];
  final aDibujo = [for (final c in cs) ...c.lat((f) => f.tDraw - f.tPose)];
  final total = [for (final c in medibles) ...c.lat((f) => f.tDraw - f.tFrame)];
  void linea(String n, List<double> v, [String nota = '']) => out.writeln(
      '  ${n.padRight(34)} n=${v.length.toString().padLeft(4)}  media '
      '${f1(media(v)).padLeft(6)}  p95 ${f1(percentil(v, 95)).padLeft(6)}'
      '  mediana ${f1(mediana(v)).padLeft(6)}$nota');
  linea('espera de muestreo (dispatch−frame)', muestreo);
  if (medibles.isEmpty) {
    out.writeln('  detección (result−dispatch)        no medible: ver avisos de '
        'emparejamiento');
  } else {
    linea('detección (result−dispatch)', deteccion,
        '  (un valor por resultado)');
    linea('resultado→pose (pose−result)', aPose,
        cs.any((c) => c.emparejamiento == 'fifo')
            ? '  (manos: incluye esperar el siguiente fotograma)'
            : '');
  }
  linea('pose→dibujo (draw−pose)', aDibujo);
  if (medibles.isNotEmpty) linea('fotograma→dibujo (draw−frame)', total);
  final periodos = [for (final c in cs) ...c.periodosDespacho()];
  linea('periodo entre despachos', periodos, '  (informativo)');

  out.writeln();
  out.writeln('Retardo del filtro (correlación cruzada sin filtrar vs. filtrada, '
      'tramo en movimiento):');
  final retardos = <double>[];
  for (final c in cs) {
    final r = c.retardoFiltro();
    if (r == null) {
      out.writeln('  ${c.nombre}: no se pudo calcular (pocas muestras en '
          'movimiento)');
    } else {
      retardos.add(r.ms);
      out.writeln('  ${c.nombre}: ${f0(r.ms)} ms (correlación ${f2(r.pico)})');
    }
  }
  if (retardos.isNotEmpty) {
    out.writeln('  media ${f0(media(retardos))} ms '
        '(mín ${f0(retardos.reduce(math.min))}, máx '
        '${f0(retardos.reduce(math.max))})');
  }

  out.writeln();
  out.writeln('Suma estimada frente al objetivo de 250 ms (medias):');
  final mMuestreo = media(muestreo);
  final mDeteccion = medibles.isEmpty ? double.nan : media(deteccion);
  final mFiltro = retardos.isEmpty ? double.nan : media(retardos);
  final mAPose = medibles.isEmpty ? double.nan : media(aPose);
  final mDibujo = media(aDibujo);
  final rd02 = mMuestreo + mDeteccion + mFiltro;
  final completo = rd02 + mAPose + mDibujo;
  out.writeln('  definición del SRS (detección + muestreo + filtro): '
      '${f0(mDeteccion)} + ${f0(mMuestreo)} + ${f0(mFiltro)} = ${f0(rd02)} ms '
      '— ${cumple(rd02, 250)} ≤ 250 ms');
  out.writeln('  con los demás tramos medidos (+ resultado→pose '
      '${f0(mAPose)} + pose→dibujo ${f0(mDibujo)}): ${f0(completo)} ms '
      '— ${cumple(completo, 250)} ≤ 250 ms');
  out.writeln('  Sin la latencia del sensor a Dart ni la de la pantalla '
      '(no medibles por software).');

  if (cs.first.categoria == 'earring' && cs.first.plataforma == 'android') {
    out.writeln();
    out.writeln('Aretes en Android (malla facial):');
    final ups = [for (final c in cs) c.resultadosPorSegundo()];
    final pps = [for (final c in cs) c.posesPorSegundo()];
    out.writeln('  actualizaciones de cabeza por segundo (resultados nuevos): '
        '${ups.map(f1).join(', ')} — media ${f1(media(ups))}');
    out.writeln('  poses publicadas por segundo: '
        '${pps.map(f1).join(', ')} — media ${f1(media(pps))}');
    out.writeln('  ms por detección (result−dispatch): media '
        '${f1(media(deteccion))}, p95 ${f1(percentil(deteccion, 95))}');
  }
}

enum Tramo {
  reposo('reposo'),
  movimiento('movimiento');

  final String etiqueta;
  const Tramo(this.etiqueta);
}

class Fila {
  final int seq;
  final int? idResultado;
  final int nDespachos, nResultados;
  final int? pendientes;
  final double tFrame, tDispatch, tResult, tPose, tDraw;
  final double rawPx, rawPy, filtPx, filtPy, dpr;

  /// Milisegundos desde «Iniciar medición» (NaN si no se inició) y fase del
  /// protocolo que anotó la app.
  final double tProt;
  final String fase;

  /// Segundos desde el inicio del protocolo o, si no se usó, desde la primera
  /// pose de la corrida.
  double t = 0;

  Fila(Map<String, String> c)
      : seq = int.parse(c['seq']!),
        idResultado = int.tryParse(c['id_resultado'] ?? ''),
        pendientes = int.tryParse(c['pendientes'] ?? ''),
        nDespachos = int.parse(c['n_despachos']!),
        nResultados = int.parse(c['n_resultados']!),
        tFrame = leer(c['t_frame']),
        tDispatch = leer(c['t_dispatch']),
        tResult = leer(c['t_result']),
        tPose = leer(c['t_pose']),
        tDraw = leer(c['t_draw']),
        rawPx = leer(c['raw_px']),
        rawPy = leer(c['raw_py']),
        filtPx = leer(c['filt_px']),
        filtPy = leer(c['filt_py']),
        dpr = leer(c['dpr']),
        tProt = leer(c['t_prot']),
        fase = c['fase'] ?? '';

  static double leer(String? s) =>
      (s == null || s.isEmpty) ? double.nan : double.parse(s);
}

class Corrida {
  final String nombre;
  final Map<String, String> meta;
  final List<Fila> filas;
  final double reposo, duracion, margen;

  Corrida(this.nombre, this.meta, this.filas, this.reposo, this.duracion,
      this.margen, this.base);

  factory Corrida.leer(File f, double reposo, double duracion, double margen) {
    final meta = <String, String>{};
    List<String>? cols;
    final filas = <Fila>[];
    for (final l in f.readAsLinesSync()) {
      if (l.trim().isEmpty) continue;
      if (l.startsWith('#')) {
        for (final m in RegExp(r'(\w+)=(\S+)').allMatches(l)) {
          meta[m.group(1)!] = m.group(2)!;
        }
        continue;
      }
      final v = l.split(',');
      if (cols == null) {
        cols = v;
        continue;
      }
      filas.add(Fila({for (var i = 0; i < cols.length; i++) cols[i]: v[i]}));
    }
    // Con la guía en pantalla los tramos se cuentan desde «Iniciar medición»
    // (las poses previas quedan fuera); sin ella, desde la primera pose.
    final conProtocolo = filas.any((r) => !r.tProt.isNaN);
    if (conProtocolo) {
      for (final r in filas) {
        r.t = r.tProt.isNaN ? double.negativeInfinity : r.tProt / 1000;
      }
    } else if (filas.isNotEmpty) {
      final t0 = filas.first.tPose;
      for (final r in filas) {
        r.t = (r.tPose - t0) / 1000;
      }
    }
    final nombre = f.uri.pathSegments.last;
    return Corrida(nombre, meta, filas, reposo, duracion, margen,
        conProtocolo ? 'inicio de la medición' : 'primera pose');
  }

  /// Desde dónde se cuentan los tramos.
  final String base;

  String get categoria => meta['categoria'] ?? '?';
  String get plataforma => meta['plataforma'] ?? '?';
  String get compilacion => meta['compilacion'] ?? '?';
  String get modoDetector => meta['modo_detector'] ?? '?';
  String get emparejamiento => meta['emparejamiento'] ?? '?';
  double get span => filas.isEmpty ? 0 : filas.last.t;

  /// Poses dentro de la ventana de medición (los dos tramos con su margen).
  int get posesEnVentana => filas.where(enVentana).length;

  bool enTramo(Fila r, Tramo t) => switch (t) {
        Tramo.reposo => r.t >= margen && r.t <= reposo - margen,
        Tramo.movimiento => r.t >= reposo + margen && r.t <= duracion - margen,
      };

  bool enVentana(Fila r) => r.t >= margen && r.t <= duracion - margen;

  /// Verificación del emparejamiento por orden (manos en Android).
  ///
  /// El plugin entrega un resultado por fotograma procesado sin decir de cuál
  /// es. Si MediaPipe descarta un fotograma, todos los resultados siguientes
  /// quedan emparejados con un fotograma anterior al suyo. Dos pruebas:
  ///
  /// - **Desfase +1 refutado:** con un descarte, cada resultado posterior
  ///   sería del fotograma siguiente al emparejado. Si un resultado llegó
  ///   *antes* de que se despachara ese fotograma siguiente, la hipótesis es
  ///   imposible en ese punto: hasta ahí no hubo descartes (el desfase solo
  ///   puede crecer con el tiempo).
  /// - **Sin crecimiento después:** `despachos − resultados` (lo que está en
  ///   vuelo más lo descartado) no puede subir después de la última
  ///   refutación. Si sube, hubo un descarte a partir de ahí.
  ({bool crece, int refutaciones}) get pruebaFifo {
    if (filas.length < 10) return (crece: true, refutaciones: 0);
    final despacho = <int, double>{
      for (final r in filas)
        if (r.idResultado != null) r.idResultado!: r.tDispatch,
    };
    var refutaciones = 0, ultima = -1;
    for (var i = 0; i < filas.length; i++) {
      final r = filas[i];
      final siguiente = despacho[(r.idResultado ?? -2) + 1];
      if (siguiente != null && r.tResult < siguiente) {
        refutaciones++;
        ultima = i;
      }
    }
    if (ultima < 0) return (crece: false, refutaciones: 0);
    int maxDif(Iterable<Fila> fs) => fs.isEmpty
        ? 0
        : fs.map((r) => r.nDespachos - r.nResultados).reduce(math.max);
    final crece =
        maxDif(filas.skip(ultima + 1)) > maxDif(filas.take(ultima + 1));
    return (crece: crece, refutaciones: refutaciones);
  }

  /// Si `t_result − t_dispatch` corresponde de verdad al mismo fotograma.
  bool get detectorMedible => switch (emparejamiento) {
        'directo' || 'id' => true,
        'fifo' => !pruebaFifo.crece && pruebaFifo.refutaciones > 0,
        _ => false,
      };

  String? avisoEmparejamiento() {
    switch (emparejamiento) {
      case 'fifo':
        final p = pruebaFifo;
        if (detectorMedible) {
          return 'emparejamiento por orden verificado: sin crecimiento de '
              'despachos−resultados y desfase +1 refutado por '
              '${p.refutaciones} resultado(s).';
        }
        return 'no se puede asegurar a qué fotograma pertenece cada resultado '
            '(${p.crece ? 'despachos−resultados crece: hubo descartes' : 'no se pudo refutar un descarte al inicio'}): '
            'no se usa su tiempo de detección.';
      case 'ultimo':
        return 'el detector responde con su último resultado: no se sabe de '
            'qué fotograma es, así que su tiempo de detección no es medible.';
    }
    return null;
  }

  List<double> errores(Tramo t, {required bool fisico}) => [
        for (final r in filas)
          if (enTramo(r, t) && !r.rawPx.isNaN && !r.filtPx.isNaN)
            math.sqrt(math.pow(r.filtPx - r.rawPx, 2) +
                    math.pow(r.filtPy - r.rawPy, 2)) *
                (fisico ? r.dpr : 1),
      ];

  List<double> lat(double Function(Fila) f) => [
        for (final r in filas)
          if (enVentana(r) && !f(r).isNaN) f(r),
      ];

  /// `t_result − t_dispatch`, una vez por resultado (varias poses pueden
  /// salir del mismo).
  List<double> detecciones() {
    final vistos = <int>{};
    return [
      for (final r in filas)
        if (enVentana(r) &&
            r.idResultado != null &&
            vistos.add(r.idResultado!) &&
            !(r.tResult - r.tDispatch).isNaN)
          r.tResult - r.tDispatch,
    ];
  }

  List<double> periodosDespacho() {
    final vistos = <int, double>{};
    for (final r in filas) {
      if (enVentana(r) && r.idResultado != null && !r.tDispatch.isNaN) {
        vistos[r.idResultado!] = r.tDispatch;
      }
    }
    final ts = vistos.values.toList()..sort();
    return [for (var i = 1; i < ts.length; i++) ts[i] - ts[i - 1]];
  }

  double resultadosPorSegundo() {
    final v = filas.where(enVentana).toList();
    if (v.length < 2) return double.nan;
    final ids = v.map((r) => r.idResultado).whereType<int>().toSet();
    return ids.length / (v.last.t - v.first.t);
  }

  double posesPorSegundo() {
    final v = filas.where(enVentana).toList();
    if (v.length < 2) return double.nan;
    return (v.length - 1) / (v.last.t - v.first.t);
  }

  double velocidadMediana(Tramo t) {
    final v = filas.where((r) => enTramo(r, t) && !r.filtPx.isNaN).toList();
    final vel = <double>[];
    for (var i = 1; i < v.length; i++) {
      final dt = v[i].t - v[i - 1].t;
      if (dt <= 0) continue;
      vel.add(math.sqrt(math.pow(v[i].filtPx - v[i - 1].filtPx, 2) +
              math.pow(v[i].filtPy - v[i - 1].filtPy, 2)) /
          dt);
    }
    return mediana(vel);
  }

  /// Desfase que maximiza la correlación entre la señal filtrada y la sin
  /// filtrar desplazada, `filtrada(t) ≈ sinFiltrar(t − τ)`, con las dos
  /// coordenadas en píxeles, en el tramo en movimiento. Se remuestrean a 1 ms
  /// por interpolación lineal y se refina el pico con una parábola.
  ({double ms, double pico})? retardoFiltro() {
    final v = filas
        .where((r) => enTramo(r, Tramo.movimiento) && !r.filtPx.isNaN)
        .toList();
    if (v.length < 20) return null;
    final ts = [for (final r in v) r.tPose];
    double interp(List<double> ys, double t) {
      if (t <= ts.first) return ys.first;
      if (t >= ts.last) return ys.last;
      var lo = 0, hi = ts.length - 1;
      while (hi - lo > 1) {
        final m = (lo + hi) >> 1;
        if (ts[m] <= t) {
          lo = m;
        } else {
          hi = m;
        }
      }
      final a = (t - ts[lo]) / (ts[hi] - ts[lo]);
      return ys[lo] + (ys[hi] - ys[lo]) * a;
    }

    List<double> centrar(List<double> xs) {
      final m = media(xs);
      return [for (final x in xs) x - m];
    }

    final rx = centrar([for (final r in v) r.rawPx]);
    final ry = centrar([for (final r in v) r.rawPy]);
    final fx = centrar([for (final r in v) r.filtPx]);
    final fy = centrar([for (final r in v) r.filtPy]);
    const maxLag = 500;
    final t0 = ts.first + maxLag, t1 = ts.last;
    if (t1 - t0 < 2000) return null;
    final grid = [for (var t = t0; t <= t1; t += 1) t];
    final gfx = [for (final t in grid) interp(fx, t)];
    final gfy = [for (final t in grid) interp(fy, t)];
    final nf = math.sqrt(
        [for (var i = 0; i < grid.length; i++) gfx[i] * gfx[i] + gfy[i] * gfy[i]]
            .reduce((a, b) => a + b));
    final corr = <double>[];
    for (var lag = 0; lag <= maxLag; lag++) {
      var s = 0.0, nr = 0.0;
      for (var i = 0; i < grid.length; i++) {
        final x = interp(rx, grid[i] - lag), y = interp(ry, grid[i] - lag);
        s += gfx[i] * x + gfy[i] * y;
        nr += x * x + y * y;
      }
      corr.add(s / (nf * math.sqrt(nr)));
    }
    var k = 0;
    for (var i = 1; i < corr.length; i++) {
      if (corr[i] > corr[k]) k = i;
    }
    var lag = k.toDouble();
    if (k > 0 && k < corr.length - 1) {
      final a = corr[k - 1], b = corr[k], c = corr[k + 1];
      final den = a - 2 * b + c;
      if (den != 0) lag += 0.5 * (a - c) / den;
    }
    return (ms: lag, pico: corr[k]);
  }
}

double media(List<double> v) =>
    v.isEmpty ? double.nan : v.reduce((a, b) => a + b) / v.length;

double maximo(List<double> v) => v.isEmpty ? double.nan : v.reduce(math.max);

double mediana(List<double> v) => percentil(v, 50);

/// Percentil con interpolación lineal entre rangos (como numpy por defecto).
double percentil(List<double> v, double p) {
  if (v.isEmpty) return double.nan;
  final s = [...v]..sort();
  final pos = (s.length - 1) * p / 100;
  final lo = pos.floor(), hi = pos.ceil();
  return s[lo] + (s[hi] - s[lo]) * (pos - lo);
}

String cumple(double v, double limite) =>
    v.isNaN ? 'sin dato' : (v <= limite ? 'CUMPLE' : 'NO CUMPLE');

String f0(double v) => v.isNaN ? '—' : v.toStringAsFixed(0);
String f1(double v) => v.isNaN ? '—' : v.toStringAsFixed(1);
String f2(double v) => v.isNaN ? '—' : v.toStringAsFixed(2);

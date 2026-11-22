import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/metrics/tracking_metrics.dart';

/// Guía en pantalla del protocolo de medición EC-03. Solo se construye con
/// `--dart-define=METRICS=true` (ver `TrackingMetrics`).
///
/// Con la joya ya en su sitio se toca «Iniciar medición». Entonces cuenta
/// [TrackingMetrics.reposoMs] con la indicación QUIETO y
/// [TrackingMetrics.movimientoMs] con MUEVE. Cada pose del CSV lleva la fase y
/// el tiempo desde el toque, así que el reporte separa reposo y movimiento con
/// el reloj de la app y no con una cuenta de memoria.
class Ec03ProtocolOverlay extends StatefulWidget {
  const Ec03ProtocolOverlay({super.key});

  @override
  State<Ec03ProtocolOverlay> createState() => _Ec03ProtocolOverlayState();
}

class _Ec03ProtocolOverlayState extends State<Ec03ProtocolOverlay> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = TrackingMetrics.instance;
    final inicio = m.inicioProtocolo;

    final Widget contenido;
    if (inicio == null) {
      contenido = FilledButton(
        onPressed: m.sesionActiva ? () => setState(m.iniciarProtocolo) : null,
        child: const Text('Iniciar medición EC-03'),
      );
    } else {
      final t = m.ahora() - inicio;
      const reposo = TrackingMetrics.reposoMs;
      const total = reposo + TrackingMetrics.movimientoMs;
      final (texto, color) = t < reposo
          ? ('QUIETO  ${((reposo - t) / 1000).ceil()}', Colors.blueGrey)
          : t < total
              ? ('MUEVE  ${((total - t) / 1000).ceil()}', Colors.deepOrange)
              : ('Listo: toca «Finalizar prueba»', Colors.green);
      contenido = DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: contenido,
      ),
    );
  }
}

// Spike B8 — ¿sirve la segmentación para medir el brazo?
//
// El anclaje actual no mide el brazo: lo deduce de la mano. MediaPipe Hands
// solo ve 21 puntos de la mano, y el último es la muñeca, así que la posición
// de la pieza, el ancho del miembro y su eje son extrapolaciones a partir de
// la palma. Por eso todo varía con el escorzo cuando cambia el ángulo de la
// cámara, que es lo que se observa en dispositivo.
//
// La segmentación mediría la silueta real. Pero el modelo de ML Kit está
// entrenado para **selfies**: persona de frente, cámara frontal. Aquí se le va
// a dar un brazo sobre un escritorio visto por la cámara trasera, que es un
// caso muy distinto. La pregunta que decide si vale la pena seguir es una
// sola: **¿segmenta el brazo?**
//
// Se pinta la máscara en verde sobre la imagen. O cubre el brazo, o no.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';

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
  final _segmenter = SelfieSegmenter(mode: SegmenterMode.stream);

  SegmentationMask? _mask;
  String estado = 'iniciando...';
  int _sensorOrientation = 0;

  bool _ocupado = false;
  int _frames = 0;
  DateTime _desde = DateTime.now();
  double hz = 0;

  /// Umbral de confianza para considerar un pixel parte del sujeto.
  static const double _umbral = 0.5;

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
    // Trasera: es la que usa la prueba de pulseras, y el caso dificil para un
    // modelo pensado para selfies.
    final trasera = camaras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => camaras.first,
    );
    _sensorOrientation = trasera.sensorOrientation;

    final controller = CameraController(
      trasera,
      ResolutionPreset.medium,
      enableAudio: false,
      // ML Kit necesita un solo plano.
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

      final mask = await _segmenter.processImage(input);

      _frames++;
      final ms = DateTime.now().difference(_desde).inMilliseconds;
      if (ms >= 1000) {
        hz = _frames * 1000 / ms;
        _frames = 0;
        _desde = DateTime.now();
      }

      if (mounted) {
        setState(() {
          _mask = mask;
          estado = mask == null
              ? 'sin mascara'
              : 'mascara ${mask.width}x${mask.height} · ${hz.toStringAsFixed(1)} Hz';
        });
      }
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
    _segmenter.close();
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

          if (_mask != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _MaskPainter(_mask!, _umbral),
                ),
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
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

/// Pinta la máscara en verde. Se dibuja en rejilla gruesa a propósito: lo que
/// se está comprobando es **si cubre el brazo**, no el detalle de su borde, y
/// recorrer cada píxel en Dart costaría más de lo que aporta.
class _MaskPainter extends CustomPainter {
  final SegmentationMask mask;
  final double umbral;

  const _MaskPainter(this.mask, this.umbral);

  static const int _paso = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final celdaX = size.width / mask.width * _paso;
    final celdaY = size.height / mask.height * _paso;
    final paint = Paint()..color = const Color(0x8800FF66);

    for (var y = 0; y < mask.height; y += _paso) {
      for (var x = 0; x < mask.width; x += _paso) {
        if (mask.confidences[y * mask.width + x] < umbral) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            x / mask.width * size.width,
            y / mask.height * size.height,
            celdaX,
            celdaY,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MaskPainter oldDelegate) => true;
}

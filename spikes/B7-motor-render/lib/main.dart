// Spike B7 — motor de render 3D para la prueba virtual.
//
// Primera parte (resuelta): ¿puede `three_js` renderizar con fondo
// transparente, de modo que lo que esté detrás se vea a través? Sí.
//
// Segunda parte (esta): ¿pueden convivir el render 3D y el stream de cámara a
// una tasa usable en el dispositivo objetivo? Es el riesgo que decide si la
// migración del render es viable, porque el presupuesto por frame ya está
// ajustado (ver ADR-12: detección a ~10 FPS).
//
// El fondo ya no son franjas sino la cámara real: además de medir, es la
// primera vista de cómo se verá la joya con el motor nuevo.

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

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
  // Se crea tarde, no en initState: `ThreeJS` lee MediaQuery en su primer
  // build y **cachea** ese tamano para siempre. En arranque en frio ese primer
  // build ocurre antes de que lleguen las medidas de la ventana, el tamano
  // queda en 0x0 y crear la textura falla con "Invalid dimensions".
  three.ThreeJS? threeJs;

  CameraController? camera;
  String estado = 'iniciando...';

  // Medicion de la tasa de render 3D: se cuenta en el callback de animacion,
  // que es donde three_js dibuja cada frame.
  int _frames = 0;
  DateTime _desde = DateTime.now();
  double fps = 0;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    // El plugin `camera` pide el permiso al inicializar en Android, asi que no
    // hace falta un gestor de permisos aparte en el spike.
    final camaras = await availableCameras();
    if (camaras.isEmpty) {
      setState(() => estado = 'sin camaras disponibles');
      return;
    }
    // Trasera: es la que usa la prueba de pulseras.
    final trasera = camaras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => camaras.first,
    );

    final controller = CameraController(
      trasera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();
    if (!mounted) return;
    setState(() {
      camera = controller;
      estado = 'camara lista';
    });
  }

  void _createViewer(Size size) {
    threeJs = three.ThreeJS(
      size: size,
      settings: three.Settings(
        alpha: true,
        clearAlpha: 0.0,
        clearColor: 0x000000,
        antialias: true,
      ),
      onSetupComplete: () => setState(() => estado = 'render + camara activos'),
      setup: setup,
    );
    setState(() {});
  }

  @override
  void dispose() {
    threeJs?.dispose();
    camera?.dispose();
    super.dispose();
  }

  Future<void> setup() async {
    final threeJs = this.threeJs!;
    threeJs.scene = three.Scene();
    threeJs.camera = three.PerspectiveCamera(
      45,
      threeJs.width / threeJs.height,
      0.1,
      100,
    );
    threeJs.camera.position.setValues(0, 0, 4);
    threeJs.camera.lookAt(threeJs.scene.position);

    threeJs.scene.add(three.AmbientLight(0xffffff, 1.2));
    final key = three.DirectionalLight(0xffffff, 2.0);
    key.position.setValues(2, 4, 3);
    threeJs.scene.add(key);

    // Se usa un modelo del catalogo que sí carga (los que traen
    // KHR_materials_specular con specularFactor entero fallan: ver README §3.2).
    three.Object3D? jewel;
    try {
      final loader = three.GLTFLoader().setPath('assets/');
      final gltf = await loader.fromAsset('cartier.glb');
      if (gltf != null) {
        jewel = gltf.scene;
        threeJs.scene.add(jewel);
      }
    } catch (_) {
      // Si falla el modelo, el spike sigue siendo valido: lo que se mide es la
      // convivencia de render y camara, no la carga.
    }

    final model = jewel;
    threeJs.addAnimationEvent((dt) {
      if (model != null) model.rotation.y += dt * 0.7;

      _frames++;
      final transcurrido = DateTime.now().difference(_desde).inMilliseconds;
      if (transcurrido >= 1000) {
        final medido = _frames * 1000 / transcurrido;
        _frames = 0;
        _desde = DateTime.now();
        if (mounted) setState(() => fps = medido);
      }
    });
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

          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (threeJs == null &&
                    constraints.maxWidth > 0 &&
                    constraints.maxHeight > 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && threeJs == null) {
                      _createViewer(
                        Size(constraints.maxWidth, constraints.maxHeight),
                      );
                    }
                  });
                }
                return threeJs?.build() ?? const SizedBox.shrink();
              },
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Column(
              children: [
                _Chip('render 3D: ${fps.toStringAsFixed(1)} FPS'),
                const SizedBox(height: 8),
                _Chip(estado),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: Colors.black87,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      );
}

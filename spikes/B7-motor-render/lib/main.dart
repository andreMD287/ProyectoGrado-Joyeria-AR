// Spike: ¿puede `three_js` renderizar con fondo transparente, de modo que lo
// que esté detrás en el árbol de widgets se vea a través?
//
// Es la pregunta que decide si sirve como motor de render para la prueba
// virtual: si el fondo no es transparente, no se puede componer la joya sobre
// la vista de cámara y el motor queda descartado.
//
// El fondo son franjas de colores fuertes a propósito: o se ven a través del
// render 3D, o no se ven. No hay término medio ni interpretación posible.

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
  // queda en 0x0 y crear la textura falla con "Invalid dimensions". Por eso se
  // espera a tener restricciones reales y se le pasa el tamano explicito.
  three.ThreeJS? threeJs;

  String glbStatus = 'GLB: cargando...';
  bool ready = false;

  void _createViewer(Size size) {
    threeJs = three.ThreeJS(
      size: size,
      settings: three.Settings(
        // Las tres lineas que se estan probando.
        alpha: true,
        clearAlpha: 0.0,
        clearColor: 0x000000,
        antialias: true,
      ),
      onSetupComplete: () => setState(() => ready = true),
      setup: setup,
    );
    setState(() {});
  }

  @override
  void dispose() {
    threeJs?.dispose();
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
    threeJs.camera.position.setValues(0, 0, 5);
    threeJs.camera.lookAt(threeJs.scene.position);

    threeJs.scene.add(three.AmbientLight(0xffffff, 1.2));
    final key = three.DirectionalLight(0xffffff, 2.0);
    key.position.setValues(2, 4, 3);
    threeJs.scene.add(key);

    // Geometria propia: no depende de cargar nada, asi que si el render
    // funciona, esto se ve si o si. Es la prueba de la transparencia.
    final knot = three.Mesh(
      three.TorusKnotGeometry(0.8, 0.28, 128, 24),
      three.MeshStandardMaterial.fromMap({
        'color': 0xD4AF37,
        'metalness': 0.9,
        'roughness': 0.25,
      }),
    );
    threeJs.scene.add(knot);

    // Prueba aparte: que el loader acepte los GLB reales del catalogo.
    // Se prueban todos para distinguir "este modelo trae algo raro" de "el
    // loader no sirve para nuestros modelos".
    const modelos = [
      'collar-cadena-01.glb',
      'cartier.glb',
      'arete_perla.glb',
      '_placeholder.glb',
      'Collar1_Juanes.glb',
      'Collar2_Juanes.glb',
      'pulsera_perlas_basica.glb',
    ];

    final resultados = <String>[];
    three.Object3D? jewel;

    for (final nombre in modelos) {
      try {
        final loader = three.GLTFLoader().setPath('assets/');
        final gltf = await loader.fromAsset(nombre);
        if (gltf == null) {
          resultados.add('x $nombre: null');
        } else {
          resultados.add('OK $nombre');
          jewel ??= gltf.scene;
        }
      } catch (e) {
        final msg = e.toString();
        resultados.add(
          'x $nombre: ${msg.length > 42 ? '${msg.substring(0, 42)}...' : msg}',
        );
      }
    }

    if (jewel != null) {
      jewel.position.setValues(0, -1.8, 0);
      threeJs.scene.add(jewel);
    }
    setState(() => glbStatus = resultados.join('\n'));

    final model = jewel;
    threeJs.addAnimationEvent((dt) {
      knot.rotation.y += dt * 0.8;
      knot.rotation.x += dt * 0.3;
      if (model != null) model.rotation.y += dt * 0.8;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo imposible de confundir: si se ve detras del 3D, hay
          // transparencia.
          Positioned.fill(
            child: CustomPaint(painter: _StripesPainter()),
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
            bottom: 24,
            child: Column(
              children: [
                _Chip(ready ? 'render listo' : 'iniciando...'),
                const SizedBox(height: 8),
                _Chip(glbStatus),
                const SizedBox(height: 8),
                const _Chip(
                  'Si ves las franjas detras del objeto -> transparencia OK',
                ),
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
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      );
}

class _StripesPainter extends CustomPainter {
  static const _colors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFDD835),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const bandHeight = 90.0;
    final paint = Paint();
    var i = 0;
    for (var y = 0.0; y < size.height; y += bandHeight) {
      paint.color = _colors[i++ % _colors.length];
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, bandHeight), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

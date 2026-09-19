import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

import '../../../../core/math/geometry.dart';
import '../../../tracking/domain/entities/anchor_pose.dart';

/// Escena 3D que cubre toda el área de cámara y coloca la joya dentro (ADR-16).
///
/// **En qué se diferencia del overlay anterior.** `model_viewer_plus` dibujaba
/// el modelo desde su propia cámara dentro de una caja pequeña que se movía por
/// la pantalla: un *sprite*. Aquí la escena ocupa toda el área, la cámara es
/// una cámara en perspectiva, y la joya es un objeto **situado en el espacio**
/// cuya proyección cae sobre el punto de anclaje. Esa diferencia es la que
/// permite, más adelante, que un *occluder* de la extremidad la tape por el
/// buffer de profundidad.
///
/// El sistema de la cámara mira hacia -Z, con +Y hacia arriba; la pantalla
/// tiene +Y hacia abajo, de ahí los signos invertidos al convertir.
class JewelryScene extends StatefulWidget {
  /// GLB ya normalizado (ver `glb_normalizer.dart`).
  final Uint8List modelBytes;

  /// Pose de anclaje, o `null` si se perdió el tracking.
  final AnchorPose? anchor;

  /// Mapeo `cover` entre el frame de cámara y el área de dibujo; es el mismo
  /// que usa la vista previa, así que la joya cae donde el usuario la ve.
  final PreviewFit fit;

  /// Giro fijo del catálogo para corregir modelos mal orientados al exportar.
  final double staticYawDeg;

  /// Rotación extra sobre el ángulo que reporta la estrategia (una pulsera se
  /// lleva perpendicular al eje del antebrazo).
  final double rollOffset;

  /// Tamaño aparente que debe ocupar la pieza, en píxeles del área. Lo calcula
  /// quien conoce el catálogo; la escena solo lo traduce a unidades de mundo.
  final double targetSizePx;

  const JewelryScene({
    super.key,
    required this.modelBytes,
    required this.anchor,
    required this.fit,
    required this.targetSizePx,
    this.staticYawDeg = 0,
    this.rollOffset = 0,
  });

  @override
  State<JewelryScene> createState() => _JewelrySceneState();
}

class _JewelrySceneState extends State<JewelryScene> {
  /// Campo de visión vertical de la cámara virtual.
  ///
  /// Todavía **no** coincide con el de la cámara física: igualarlos es el paso
  /// siguiente, y es lo que hará que la perspectiva del modelo case con la de
  /// la imagen. Mientras tanto se comporta como el overlay anterior.
  static const double _fovY = 45;

  /// Profundidad a la que se sitúa la joya. Con la cámara virtual aún sin
  /// calibrar, el valor concreto es indiferente: lo que fija el tamaño aparente
  /// es la escala del modelo, que se calcula contra esta misma distancia.
  static const double _depth = 1.0;

  /// El visor **cachea su tamaño en el primer build**, así que no puede crearse
  /// hasta conocer las restricciones reales. Con arranque en frío el primer
  /// build llega antes que las medidas de la ventana y la textura se crearía de
  /// 0x0 (ver `spikes/B7-motor-render`).
  three.ThreeJS? _viewer;
  Size? _area;

  three.Object3D? _jewel;

  /// Ancho del modelo en unidades de mundo, ya centrado. Sirve para llevarlo a
  /// un tamaño aparente concreto sin depender de cómo lo exportaron.
  double _modelWidth = 1;

  void _createViewer(Size area) {
    _area = area;
    _viewer = three.ThreeJS(
      size: area,
      settings: three.Settings(
        // Sin esto el render tapa la cámara con un rectángulo negro.
        alpha: true,
        clearAlpha: 0.0,
        clearColor: 0x000000,
        antialias: true,
      ),
      onSetupComplete: () {
        if (mounted) setState(() {});
      },
      setup: _setup,
    );
    setState(() {});
  }

  @override
  void dispose() {
    _viewer?.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    final viewer = _viewer!;
    viewer.scene = three.Scene();
    viewer.camera = three.PerspectiveCamera(
      _fovY,
      viewer.width / viewer.height,
      0.01,
      100,
    );
    viewer.camera.position.setValues(0, 0, 0);

    // Iluminación provisional de estudio. La coherencia con la luz real de la
    // escena es la fase siguiente, y es la última pista que delata el montaje.
    viewer.scene.add(three.AmbientLight(0xffffff, 1.4));
    final key = three.DirectionalLight(0xffffff, 2.2);
    key.position.setValues(1, 2, 1);
    viewer.scene.add(key);

    final gltf = await three.GLTFLoader().fromBytes(widget.modelBytes);
    final model = gltf?.scene;
    if (model == null) return;

    // El GLB viene en la escala y el origen que le dio el exportador: se
    // centra y se mide para poder pedirle después un tamaño aparente concreto.
    final bounds = three.BoundingBox()..setFromObject(model);
    final size = bounds.max.clone()..sub(bounds.min);
    final center = bounds.getCenter(three.Vector3());

    model.position.setValues(-center.x, -center.y, -center.z);
    _modelWidth = math.max(size.x, 1e-6);

    // Un contenedor propio evita pelear con la transformación que el modelo ya
    // trae: el hijo centra, el padre posiciona y orienta.
    final holder = three.Object3D()..add(model);
    viewer.scene.add(holder);
    _jewel = holder;

    _applyAnchor();
  }

  @override
  void didUpdateWidget(covariant JewelryScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyAnchor();
  }

  /// Sitúa y orienta la joya para la pose actual.
  void _applyAnchor() {
    final jewel = _jewel;
    final area = _area;
    final anchor = widget.anchor;
    if (jewel == null || area == null) return;

    // Sin pose no se dibuja, en vez de dejarla clavada donde estaba.
    jewel.visible = anchor != null;
    if (anchor == null) return;

    // Mitad del plano visible a la profundidad de trabajo: convierte entre
    // píxeles de pantalla y unidades de mundo.
    final halfHeight = _depth * math.tan(_fovY * math.pi / 180 / 2);
    final halfWidth = halfHeight * (area.width / area.height);

    // El ancla llega normalizada al frame; se pasa por el mismo mapeo `cover`
    // que la vista previa y de ahí a coordenadas de la cámara virtual.
    final screenX = widget.fit.xOf(anchor.position.x);
    final screenY = widget.fit.yOf(anchor.position.y);
    final ndcX = screenX / area.width * 2 - 1;
    final ndcY = 1 - screenY / area.height * 2;

    jewel.position.setValues(ndcX * halfWidth, ndcY * halfHeight, -_depth);

    // Tamaño aparente: llega en píxeles y se traduce al ancho de mundo que
    // ocupa esa cantidad de píxeles a esta profundidad.
    final targetWorld = widget.targetSizePx / area.width * (2 * halfWidth);
    final factor = targetWorld / _modelWidth;
    jewel.scale.setValues(factor, factor, factor);

    // El roll llega en coordenadas de pantalla, donde +Y va hacia abajo; en la
    // escena +Y va hacia arriba, así que el giro cambia de signo.
    jewel.rotation.z = -(anchor.rollRadians + widget.rollOffset);
    jewel.rotation.y =
        widget.staticYawDeg * math.pi / 180 + (anchor.yawRadians ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        if (_viewer == null && area.width > 0 && area.height > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _viewer == null) _createViewer(area);
          });
        }
        return IgnorePointer(
          child: _viewer?.build() ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

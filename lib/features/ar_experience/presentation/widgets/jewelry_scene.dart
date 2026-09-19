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

  /// Tamaño aparente, en píxeles del área. Solo se usa cuando no hay
  /// reconstrucción métrica; entonces la pieza se dimensiona a ojo, como hacía
  /// el overlay anterior.
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
  /// Campo de visión **horizontal** del área visible, en grados.
  ///
  /// Da a la cámara virtual una perspectiva comparable a la del objetivo, que
  /// es lo que hace que un objeto girado en 3D se escorce como es debido. No se
  /// puede leer del plugin de cámara (no expone la óptica) y la vista previa
  /// recorta el frame con `cover`, así que corresponde al **área visible**.
  static const double _hfovDeg = 65;

  /// Distancia a la que se sitúa la joya.
  ///
  /// Es fija a propósito. Se intentó deducir la distancia real comparando el
  /// tamaño métrico de la mano con su tamaño aparente, y **no funciona**: la
  /// reconstrucción métrica de MediaPipe subestima la escala absoluta (mide
  /// unos 4,5 cm entre nudillos donde una mano adulta tiene ~8), así que la
  /// mano se interpreta como cercana y la pieza sale hasta tres veces más
  /// grande. Verificado en dispositivo el 2026-09-18.
  ///
  /// De esa reconstrucción se usa lo que sí es fiable —las **direcciones**,
  /// que no dependen de la escala— para orientar la pieza; el tamaño se sigue
  /// midiendo sobre la imagen, que es lo que se observa directamente.
  static const double _depth = 1.0;

  /// El visor **cachea su tamaño en el primer build**, así que no puede crearse
  /// hasta conocer las restricciones reales. Con arranque en frío el primer
  /// build llega antes que las medidas de la ventana y la textura se crearía de
  /// 0x0 (ver `spikes/B7-motor-render`).
  three.ThreeJS? _viewer;
  Size? _area;

  three.Object3D? _jewel;

  /// Diámetro del modelo: su mayor extensión. Para una pieza que rodea un
  /// miembro es el diámetro del aro, que es lo que el catálogo mide en mm.
  double _modelDiameter = 1;

  /// Eje del aro en el espacio del modelo: la dirección **de menor extensión**.
  /// Una pieza que rodea un miembro es ancha en dos ejes y delgada en el
  /// tercero, y ese tercero es por donde entra el brazo. Deducirlo de la malla
  /// evita una constante por modelo y funciona con piezas que aún no existen.
  three.Vector3 _ringAxisLocal = three.Vector3(0, 0, 1);

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
    final aspect = viewer.width / viewer.height;
    viewer.camera = three.PerspectiveCamera(
      _fovYFor(aspect),
      aspect,
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
    _modelDiameter = math.max(math.max(size.x, size.y), math.max(size.z, 1e-6));
    _ringAxisLocal = _menorExtension(size);

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

  /// Campo de visión vertical que corresponde a [_hfovDeg] con este aspecto.
  static double _fovYFor(double aspect) {
    final halfH = math.tan(_hfovDeg * math.pi / 180 / 2) / aspect;
    return 2 * math.atan(halfH) * 180 / math.pi;
  }

  /// Dirección del eje de menor extensión de una caja.
  static three.Vector3 _menorExtension(three.Vector3 size) {
    if (size.x <= size.y && size.x <= size.z) return three.Vector3(1, 0, 0);
    if (size.y <= size.z) return three.Vector3(0, 1, 0);
    return three.Vector3(0, 0, 1);
  }

  /// Sitúa, dimensiona y orienta la joya para la pose actual.
  ///
  /// Hay dos caminos. Con reconstrucción métrica la pieza se coloca a su
  /// **distancia real** y se dimensiona con los milímetros del catálogo, así
  /// que su tamaño en pantalla sale de la geometría; sin ella se cae al
  /// comportamiento anterior, con el tamaño pedido en píxeles.
  void _applyAnchor() {
    final jewel = _jewel;
    final area = _area;
    final anchor = widget.anchor;
    if (jewel == null || area == null) return;

    // Sin pose no se dibuja, en vez de dejarla clavada donde estaba.
    jewel.visible = anchor != null;
    if (anchor == null) return;

    final aspect = area.width / area.height;
    final tanHalfV = math.tan(_fovYFor(aspect) * math.pi / 180 / 2);

    final halfHeight = _depth * tanHalfV;
    final halfWidth = halfHeight * aspect;

    // El ancla llega normalizada al frame; se pasa por el mismo mapeo `cover`
    // que la vista previa y de ahí a coordenadas de la cámara virtual.
    final screenX = widget.fit.xOf(anchor.position.x);
    final screenY = widget.fit.yOf(anchor.position.y);
    final ndcX = screenX / area.width * 2 - 1;
    final ndcY = 1 - screenY / area.height * 2;

    jewel.position.setValues(ndcX * halfWidth, ndcY * halfHeight, -_depth);

    // El tamaño se pide en píxeles y se traduce al ancho de mundo que ocupan a
    // esta distancia. Se compara contra el diámetro del modelo —su mayor
    // extensión— porque es lo que debe casar con el ancho de la muñeca.
    final targetWorld = widget.targetSizePx / area.width * (2 * halfWidth);
    final factor = targetWorld / _modelDiameter;
    jewel.scale.setValues(factor, factor, factor);

    _applyOrientation(jewel, anchor);
  }

  void _applyOrientation(three.Object3D jewel, AnchorPose anchor) {
    final axis = anchor.axis3D;

    if (axis == null) {
      // Sin eje real solo queda girar en el plano de la pantalla, como antes.
      jewel.rotation.z = -(anchor.rollRadians + widget.rollOffset);
      jewel.rotation.y =
          widget.staticYawDeg * math.pi / 180 + (anchor.yawRadians ?? 0);
      return;
    }

    // El eje llega en el marco del detector (y hacia abajo, z alejándose) y la
    // escena usa el de la cámara (y hacia arriba, z hacia el espectador).
    final destino = three.Vector3(axis.x, -axis.y, -axis.z)..normalize();

    // Se alinea el eje del aro con el del antebrazo, y luego se gira la pieza
    // sobre ese mismo eje para colocar el detalle (dije, broche) donde va.
    final alinear = three.Quaternion()
      ..setFromUnitVectors(_ringAxisLocal, destino);
    final girar = three.Quaternion()
      ..setFromAxisAngle(_ringAxisLocal, widget.staticYawDeg * math.pi / 180);

    jewel.quaternion.setFrom(alinear..multiply(girar));
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

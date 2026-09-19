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

  /// Diámetro **exterior** que debe aparentar la pieza, en píxeles del área.
  final double targetSizePx;

  /// Diámetro del miembro que la pieza rodea, en píxeles del área. Es lo que
  /// ocluye, y **no se deduce del modelo**: la caja envolvente no da el hueco
  /// del aro. En una pieza de cuentas su dimensión más delgada es el grosor de
  /// la cuenta, pero en un brazalete es el ancho de la banda a lo largo del
  /// brazo, que no guarda relación con el radio interior. Se estima por
  /// anatomía a partir de la medida que reporta la estrategia.
  ///
  /// `null` en piezas que no rodean nada (aretes): entonces no hay oclusión.
  final double? limbDiameterPx;


  const JewelryScene({
    super.key,
    required this.modelBytes,
    required this.anchor,
    required this.fit,
    required this.targetSizePx,
    this.limbDiameterPx,
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

  /// Cilindro que representa la extremidad. No se pinta: solo escribe
  /// profundidad, de modo que el arco de la pieza que pasa por detrás queda
  /// tapado por el propio buffer. Es la oclusión real, con silueta curva, en
  /// lugar de un recorte plano sobre la imagen.
  three.Object3D? _occluder;

  /// Largo del cilindro en diámetros de hueco: basta con que sobresalga por
  /// ambos lados para tapar en cualquier inclinación.
  static const double _occluderLengthRatio = 3.0;

  /// Diámetro exterior del modelo: su mayor extensión.
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

    // Se dibuja antes que la joya (renderOrder menor) para que su profundidad
    // ya esté en el buffer cuando se pinte la pieza.
    final occluder = three.Mesh(
      three.CylinderGeometry(0.5, 0.5, 1, 48),
      three.MeshBasicMaterial.fromMap({'colorWrite': false}),
    )..renderOrder = -1;
    viewer.scene.add(occluder);
    _occluder = occluder;

    final gltf = await three.GLTFLoader().fromBytes(widget.modelBytes);
    final model = gltf?.scene;
    if (model == null) return;

    // El GLB viene en la escala y el origen que le dio el exportador: se
    // centra y se mide para poder pedirle después un tamaño aparente concreto.
    final bounds = three.BoundingBox()..setFromObject(model);
    final size = bounds.max.clone()..sub(bounds.min);
    final center = bounds.getCenter(three.Vector3());

    // Se **resta**, no se asigna: la caja viene en coordenadas de mundo, o sea
    // que su centro ya incluye la traslacion que el modelo trae del exportador.
    // Asignar `-centro` la descartaba, y la pieza quedaba desplazada de la
    // muneca justo esa cantidad (visto en dispositivo: se iba hacia un lado).
    model.position.sub(center);
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
    // esta distancia.
    final targetWorld = widget.targetSizePx / area.width * (2 * halfWidth);

    final factor = targetWorld / _modelDiameter;
    jewel.scale.setValues(factor, factor, factor);

    _applyOrientation(jewel, anchor);

    final limbPx = widget.limbDiameterPx;
    _applyOccluder(
      anchor,
      jewel,
      limbPx == null ? 0 : limbPx / area.width * (2 * halfWidth),
    );
  }

  /// Sitúa el cilindro de oclusión sobre la extremidad.
  ///
  /// Solo se activa cuando hay eje 3D: sin él no se sabe hacia dónde va el
  /// miembro, y un cilindro mal orientado taparía lo que no debe. Sin oclusión
  /// la pieza se ve entera, que es el comportamiento anterior — peor, pero no
  /// erróneo.
  void _applyOccluder(
    AnchorPose anchor,
    three.Object3D jewel,
    double limbDiameterWorld,
  ) {
    final occluder = _occluder;
    final axis = anchor.axis3D;
    if (occluder == null) return;

    // Sin eje 3D no se sabe hacia donde va el miembro; sin hueco, la pieza no
    // rodea nada y no hay nada que ocluir.
    occluder.visible = axis != null && limbDiameterWorld > 0;
    if (axis == null || limbDiameterWorld <= 0) return;

    occluder.position.setFrom(jewel.position);

    occluder.scale.setValues(
      limbDiameterWorld,
      limbDiameterWorld * _occluderLengthRatio,
      limbDiameterWorld,
    );

    // El cilindro nace con su eje en +Y; se lleva al eje del antebrazo.
    final destino = three.Vector3(axis.x, -axis.y, -axis.z)..normalize();
    occluder.quaternion.setFromUnitVectors(three.Vector3(0, 1, 0), destino);
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
    final n = three.Vector3(axis.x, -axis.y, -axis.z)..normalize();

    // Primero se alinea el eje del aro con el del antebrazo. Queda libre el
    // giro **alrededor** de ese eje, que es el que decide qué parte de la
    // pieza mira al usuario.
    final alinear = three.Quaternion()..setFromUnitVectors(_ringAxisLocal, n);

    // Ese giro libre se ata al **dorso de la mano**, no a la cámara. Atarlo a
    // la cámara mantiene el detalle siempre de frente, pero entonces la pieza
    // contrarrota al girar la muñeca y parece congelada, perdiendo justo la
    // señal de que está puesta en el brazo (visto en dispositivo). Siguiendo la
    // palma, la pieza gira con la muñeca y el detalle queda arriba con la palma
    // apoyada, que es la pose natural.
    final refWorld = _perpendicularTo(_ringAxisLocal)..applyQuaternion(alinear);

    final palma = anchor.palmNormal3D;
    final referencia = palma == null
        // Sin normal de palma se recurre a la cámara: peor, pero deja el
        // detalle visible en vez de escondido.
        ? three.Vector3(0, 0, 1)
        // Signo invertido: se apunta al **dorso** de la mano, no a la palma.
        // Es el lado que queda arriba con la palma apoyada en la mesa, que es
        // como se lleva una pulsera y como el usuario espera ver el detalle.
        : (three.Vector3(-palma.x, palma.y, palma.z)..normalize());

    // Solo interesa su componente dentro del plano del aro.
    final proyeccion = n.clone()..scale(referencia.dot(n));
    final destino = referencia.clone()..sub(proyeccion);

    var giroRadianes = widget.staticYawDeg * math.pi / 180;
    if (destino.length > 1e-6) {
      destino.normalize();
      // Ángulo con signo de `refWorld` a `destino`, medido alrededor de `n`.
      final cos = destino.dot(refWorld).clamp(-1.0, 1.0);
      final sin = (refWorld.clone()..cross(destino)).dot(n);
      giroRadianes += math.atan2(sin, cos);
    }

    // El giro es alrededor de un eje ya en coordenadas de mundo, así que se
    // aplica después de la alineación.
    final girar = three.Quaternion()..setFromAxisAngle(n, giroRadianes);
    jewel.quaternion.setFrom(girar..multiply(alinear));
  }

  /// Un unitario cualquiera perpendicular a [v]. Sirve de referencia para
  /// medir el giro alrededor del eje del aro; cuál de todos los
  /// perpendiculares sea da igual, porque el desfase hasta el detalle de la
  /// pieza lo aporta `orientacion_yaw_deg` del catálogo.
  static three.Vector3 _perpendicularTo(three.Vector3 v) {
    final auxiliar =
        v.x.abs() < 0.9 ? three.Vector3(1, 0, 0) : three.Vector3(0, 1, 0);
    return (auxiliar..cross(v)).normalize();
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

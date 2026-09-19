import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/anchor_pose.dart';
import 'package:jewelry_ar/core/math/geometry.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/landmark.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/landmark_frame.dart';
import 'package:jewelry_ar/features/tracking/domain/strategies/bracelet_strategy.dart';

/// Construye los 21 landmarks de MediaPipe Hands con todo en el origen salvo
/// los tres que usa la estrategia.
/// [world] son los 21 puntos metricos (en metros). Solo se usan los tres que
/// mira la estrategia; el resto va al origen.
LandmarkFrame hand({
  required (double, double) wrist,
  required (double, double) indexMcp,
  required (double, double) pinkyMcp,
  (double, double)? thumbTip,
  ({Vec3 wrist, Vec3 indexMcp, Vec3 pinkyMcp})? world,
}) {
  final points = List<Landmark>.filled(21, const Landmark(0, 0, 0));
  points[BraceletStrategy.wristLandmark] = Landmark(wrist.$1, wrist.$2, 0);
  points[BraceletStrategy.indexMcpLandmark] =
      Landmark(indexMcp.$1, indexMcp.$2, 0);
  points[BraceletStrategy.pinkyMcpLandmark] =
      Landmark(pinkyMcp.$1, pinkyMcp.$2, 0);
  if (thumbTip != null) {
    points[BraceletStrategy.thumbTipLandmark] =
        Landmark(thumbTip.$1, thumbTip.$2, 0);
  }
  final metricos = <Vec3>[];
  if (world != null) {
    metricos.addAll(List<Vec3>.filled(21, Vec3.zero));
    metricos[BraceletStrategy.wristLandmark] = world.wrist;
    metricos[BraceletStrategy.indexMcpLandmark] = world.indexMcp;
    metricos[BraceletStrategy.pinkyMcpLandmark] = world.pinkyMcp;
  }

  return LandmarkFrame(landmarks: points, worldLandmarks: metricos);
}

void main() {
  // Una instancia fresca por prueba: BraceletStrategy ya no es sin estado
  // (calibra un maximo de sesion para el yaw, ver bracelet_strategy.dart),
  // asi que compartir una sola instancia entre pruebas dejaria que el orden
  // de ejecucion contaminara el `scale` calculado en unas con lo calibrado
  // en otras.
  late BraceletStrategy strategy;
  setUp(() {
    strategy = BraceletStrategy();
  });

  group('anclaje en el antebrazo', () {
    test('desplaza el ancla mas alla de la muneca, alejandose de la palma', () {
      // Palma centrada en (0.5, 0.4), muneca 0.2 mas abajo: el antebrazo baja.
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
        ),
      )!;

      // muneca.y + (muneca.y - palma.y) * forearmOffset = 0.6 + 0.2 * 0.45
      expect(anchor.position.y, closeTo(0.69, 1e-9));
      expect(anchor.position.x, closeTo(0.5, 1e-9));
    });

    test('no se queda en el landmark de la muneca', () {
      const wristY = 0.6;
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, wristY),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
        ),
      )!;

      expect(anchor.position.y, greaterThan(wristY));
    });

    test('respeta la direccion de la mano, no solo el eje vertical', () {
      // Mano apuntando a la izquierda: la palma queda a la derecha del ancla.
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.4, 0.5),
          indexMcp: (0.6, 0.45),
          pinkyMcp: (0.6, 0.55),
        ),
      )!;

      expect(anchor.position.x, lessThan(0.4));
      expect(anchor.position.y, closeTo(0.5, 1e-9));
    });

    test('forearmOffset calibra cuanto se avanza hacia el codo', () {
      final points = hand(
        wrist: (0.5, 0.6),
        indexMcp: (0.4, 0.4),
        pinkyMcp: (0.6, 0.4),
      );

      final corto = BraceletStrategy(forearmOffset: 0.2)
          .computeAnchor(points)!;
      final largo = BraceletStrategy(forearmOffset: 0.8)
          .computeAnchor(points)!;

      expect(corto.position.y, lessThan(largo.position.y));
    });
  });

  group('escala', () {
    test('reporta el ancho de la palma en fracciones del ancho del frame', () {
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
        ),
      )!;

      expect(anchor.scale, closeTo(0.2, 1e-9));
    });

    test('crece cuando la mano se acerca a la camara', () {
      final lejos = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.55),
          indexMcp: (0.45, 0.5),
          pinkyMcp: (0.55, 0.5),
        ),
      )!;
      final cerca = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.8),
          indexMcp: (0.3, 0.4),
          pinkyMcp: (0.7, 0.4),
        ),
      )!;

      expect(cerca.scale!, greaterThan(lejos.scale!));
    });

    test('corrige por aspecto: una palma vertical no mide menos que una '
        'horizontal del mismo tamano real', () {
      // Frame 1:2 (mas alto que ancho). Un desplazamiento de 0.2 en y ocupa el
      // doble de pixeles que uno de 0.2 en x.
      const aspect = 0.5;

      final horizontal = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.7),
          indexMcp: (0.4, 0.5),
          pinkyMcp: (0.6, 0.5),
        ),
        imageAspect: aspect,
      )!;
      final vertical = strategy.computeAnchor(
        hand(
          wrist: (0.7, 0.5),
          indexMcp: (0.5, 0.45),
          pinkyMcp: (0.5, 0.55),
        ),
        imageAspect: aspect,
      )!;

      // 0.2 en x -> 0.2 anchos; 0.1 en y -> 0.1/0.5 = 0.2 anchos.
      expect(horizontal.scale, closeTo(0.2, 1e-9));
      expect(vertical.scale, closeTo(0.2, 1e-9));
    });
  });

  group('orientacion', () {
    test('el roll sigue el eje del antebrazo', () {
      // Antebrazo hacia abajo en pantalla: +90 grados (y crece hacia abajo).
      final abajo = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
        ),
      )!;
      expect(abajo.rollRadians, closeTo(math.pi / 2, 1e-9));

      // Antebrazo hacia la izquierda: 180 grados.
      final izquierda = strategy.computeAnchor(
        hand(
          wrist: (0.4, 0.5),
          indexMcp: (0.6, 0.45),
          pinkyMcp: (0.6, 0.55),
        ),
      )!;
      expect(izquierda.rollRadians.abs(), closeTo(math.pi, 1e-9));
    });

    test('el angulo tiene en cuenta el aspecto del frame', () {
      // Mismo desplazamiento normalizado, distinto aspecto: en un frame mas
      // alto que ancho el eje se ve mas inclinado de lo que sugiere el crudo.
      final points = hand(
        wrist: (0.6, 0.6),
        indexMcp: (0.45, 0.5),
        pinkyMcp: (0.55, 0.5),
      );

      final cuadrado = strategy.computeAnchor(points, imageAspect: 1.0)!;
      final alto = strategy.computeAnchor(points, imageAspect: 0.5)!;

      expect(cuadrado.rollRadians, closeTo(math.pi / 4, 1e-9));
      expect(alto.rollRadians, greaterThan(cuadrado.rollRadians));
      expect(alto.rollRadians, closeTo(math.atan2(0.2, 0.1), 1e-9));
    });
  });

  group('yaw aproximado (giro de muneca)', () {
    test('el primer frame calibra el maximo visto y da yaw cero', () {
      final s = BraceletStrategy();
      final anchor = s.computeAnchor(
        hand(wrist: (0.5, 0.6), indexMcp: (0.4, 0.4), pinkyMcp: (0.6, 0.4)),
      )!;

      expect(anchor.yawRadians, closeTo(0, 1e-9));
    });

    test(
        'una palma mas angosta que el maximo visto reporta mayor magnitud '
        'de yaw', () {
      final s = BraceletStrategy();
      // Calibra el maximo: ancho de palma == largo de antebrazo (ratio 1.0).
      s.computeAnchor(
        hand(wrist: (0.5, 0.6), indexMcp: (0.4, 0.4), pinkyMcp: (0.6, 0.4)),
      );
      // Palma a la mitad de ancho con el mismo largo de antebrazo: ratio 0.5.
      final anchor = s.computeAnchor(
        hand(wrist: (0.5, 0.6), indexMcp: (0.45, 0.4), pinkyMcp: (0.55, 0.4)),
      )!;

      // acos(0.5) = 60 grados = pi/3.
      expect(anchor.yawRadians!.abs(), closeTo(math.pi / 3, 1e-6));
    });

    test(
        'el lado del pulgar decide el signo, tras sostenerlo varios frames '
        '(histeresis)', () {
      final derecha = BraceletStrategy();
      derecha.computeAnchor(
        hand(wrist: (0.5, 0.6), indexMcp: (0.4, 0.4), pinkyMcp: (0.6, 0.4)),
      );
      // Lado derecho del centro de palma (x=0.5): coincide con el signo por
      // defecto, no necesita varios frames para confirmarse.
      final anchorDerecha = derecha.computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.45, 0.4),
          pinkyMcp: (0.55, 0.4),
          thumbTip: (0.6, 0.4),
        ),
      )!;

      final izquierda = BraceletStrategy();
      izquierda.computeAnchor(
        hand(wrist: (0.5, 0.6), indexMcp: (0.4, 0.4), pinkyMcp: (0.6, 0.4)),
      );
      // Lado izquierdo: contrario al signo por defecto, hace falta
      // sostenerlo varios frames (ver _minFramesToFlipSign) para que cambie.
      AnchorPose? anchorIzquierda;
      for (var i = 0; i < 3; i++) {
        anchorIzquierda = izquierda.computeAnchor(
          hand(
            wrist: (0.5, 0.6),
            indexMcp: (0.45, 0.4),
            pinkyMcp: (0.55, 0.4),
            thumbTip: (0.4, 0.4),
          ),
        );
      }

      expect(anchorDerecha.yawRadians, isPositive);
      expect(anchorIzquierda!.yawRadians, isNegative);
      expect(
        anchorDerecha.yawRadians!.abs(),
        closeTo(anchorIzquierda.yawRadians!.abs(), 1e-9),
      );
    });

    test(
        'un solo frame con la señal contraria no alcanza para voltear el '
        'signo (ruido de un solo frame)', () {
      final s = BraceletStrategy();
      s.computeAnchor(
        hand(wrist: (0.5, 0.6), indexMcp: (0.4, 0.4), pinkyMcp: (0.6, 0.4)),
      );

      final anchor = s.computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.45, 0.4),
          pinkyMcp: (0.55, 0.4),
          thumbTip: (0.4, 0.4), // propondria el lado contrario
        ),
      )!;

      // Un solo frame no basta: se mantiene el signo por defecto.
      expect(anchor.yawRadians, isPositive);
    });

    test('reset() borra el maximo calibrado', () {
      final s = BraceletStrategy();
      s.computeAnchor(
        hand(wrist: (0.5, 0.6), indexMcp: (0.4, 0.4), pinkyMcp: (0.6, 0.4)),
      );

      s.reset();

      final anchor = s.computeAnchor(
        hand(wrist: (0.5, 0.6), indexMcp: (0.45, 0.4), pinkyMcp: (0.55, 0.4)),
      )!;
      expect(anchor.yawRadians, closeTo(0, 1e-9));
    });

    test(
        'tras varios frames sin mano detectable, el siguiente frame valido '
        'recalibra el maximo desde cero', () {
      final s = BraceletStrategy();
      // Calibra con una palma ancha (ratio alto).
      s.computeAnchor(
        hand(wrist: (0.5, 0.6), indexMcp: (0.3, 0.4), pinkyMcp: (0.7, 0.4)),
      );

      // La mano sale del encuadre: varios frames sin landmarks suficientes.
      for (var i = 0; i < 3; i++) {
        s.computeAnchor(LandmarkFrame.empty);
      }

      // Reaparece con una palma mas angosta que la calibrada antes de salir.
      // Sin recalibrar, esto se leeria como un giro fuerte; al recalibrar,
      // este frame se vuelve la nueva referencia "de frente": yaw cero.
      final anchor = s.computeAnchor(
        hand(wrist: (0.5, 0.6), indexMcp: (0.45, 0.4), pinkyMcp: (0.55, 0.4)),
      )!;

      expect(anchor.yawRadians, closeTo(0, 1e-9));
    });

    test(
        'un frame con geometria degenerada no dispara el maximo mas alla '
        'del tope de sanidad', () {
      final s = BraceletStrategy();
      // axisLength casi cero (pero no cero) con palmWidth normal: sin tope,
      // el ratio crudo se dispararia a miles.
      s.computeAnchor(
        hand(
          wrist: (0.5001, 0.4001),
          indexMcp: (0.3, 0.4),
          pinkyMcp: (0.7, 0.4),
        ),
      );

      // Frame normal despues: si el maximo hubiera quedado disparado, esto
      // se leeria como un giro fuerte (cerca de 90 grados) en vez de casi 0.
      final anchor = s.computeAnchor(
        hand(wrist: (0.5, 0.6), indexMcp: (0.3, 0.4), pinkyMcp: (0.7, 0.4)),
      )!;

      expect(anchor.yawRadians!.abs(), lessThan(0.05));
    });
  });

  group('geometria 3D desde los landmarks metricos', () {
    // Mano de tamano plausible: 9 cm de la muneca al nudillo del indice y
    // 4 cm entre nudillos, que es lo que devuelve MediaPipe en dispositivo.
    ({Vec3 wrist, Vec3 indexMcp, Vec3 pinkyMcp}) manoMetrica({
      double wristZ = 0,
    }) =>
        (
          wrist: Vec3(0, 0.09, wristZ),
          indexMcp: Vec3(-0.02, 0, 0),
          pinkyMcp: Vec3(0.02, 0, 0),
        );

    test('sin puntos metricos no inventa eje ni ancho', () {
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
        ),
      )!;

      expect(anchor.axis3D, isNull);
      expect(anchor.metricWidth, isNull);
    });

    test('el ancho metrico es la distancia real entre nudillos', () {
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
          world: manoMetrica(),
        ),
      )!;

      // 4 cm entre los dos nudillos.
      expect(anchor.metricWidth, closeTo(0.04, 1e-9));
    });

    test('el eje 3D es unitario', () {
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
          world: manoMetrica(wristZ: 0.05),
        ),
      )!;

      final eje = anchor.axis3D!;
      final largo =
          math.sqrt(eje.x * eje.x + eje.y * eje.y + eje.z * eje.z);
      expect(largo, closeTo(1.0, 1e-9));
    });

    test('el eje apunta de la palma hacia el codo', () {
      // La muneca esta 9 cm "por debajo" de los nudillos en el eje y, que en
      // este marco crece hacia abajo: el antebrazo baja.
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
          world: manoMetrica(),
        ),
      )!;

      expect(anchor.axis3D!.y, greaterThan(0.9));
      expect(anchor.axis3D!.x, closeTo(0, 1e-9));
    });

    test('recoge la profundidad, pero amortiguada', () {
      // Misma proyeccion en la imagen, distinta inclinacion real: es el caso
      // que la heuristica 2D no distingue y esta si. La profundidad se refleja,
      // pero atenuada a proposito: medida en dispositivo es la componente con
      // diez veces mas ruido que las otras, y tomarla cruda hacia temblar la
      // pieza (ver _depthDamping).
      final plano = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
          world: manoMetrica(),
        ),
      )!;

      final inclinado = BraceletStrategy().computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
          world: manoMetrica(wristZ: 0.09),
        ),
      )!;

      expect(plano.axis3D!.z, closeTo(0, 1e-9));
      // Sin amortiguar, un antebrazo a 45 grados daria z ~0,71.
      expect(inclinado.axis3D!.z, greaterThan(0.1));
      expect(inclinado.axis3D!.z, lessThan(0.4));
      // La direccion en el plano de la imagen sigue dominando, que es la que
      // el detector si resuelve bien.
      expect(inclinado.axis3D!.y, greaterThan(inclinado.axis3D!.z * 2));
    });
  });

  group('tamano de la pieza', () {
    // Mano metrica de referencia, en metros: 9 cm de la muneca al plano de los
    // nudillos y 4 cm entre ellos.
    const wristW = Vec3(0, 0.09, 0);
    const indexW = Vec3(-0.02, 0, 0);
    const pinkyW = Vec3(0.02, 0, 0);

    /// Proyecta una mano metrica a la imagen con una escala conocida. Es lo que
    /// hace la camara, y es lo que el algoritmo tiene que recuperar: si los
    /// landmarks de imagen y los metricos no describen la misma mano, la
    /// prueba mide una incoherencia inventada y no el comportamiento real.
    LandmarkFrame proyectar(
      Vec3 w,
      Vec3 i,
      Vec3 p, {
      required double escala,
    }) {
      (double, double) img(Vec3 v) => (0.5 + v.x * escala, 0.5 + v.y * escala);
      return hand(
        wrist: img(w),
        indexMcp: img(i),
        pinkyMcp: img(p),
        world: (wrist: w, indexMcp: i, pinkyMcp: p),
      );
    }

    test('el tamano sale del ancho de palma medido en la imagen', () {
      final anchor = strategy.computeAnchor(
        proyectar(wristW, indexW, pinkyW, escala: 2.0),
      )!;

      // 4 cm de palma proyectados con escala 2.0.
      expect(anchor.scale, closeTo(0.04 * 2.0, 1e-9));
    });

    test('el tamano sigue al escorzo, y eso se acepta a conciencia', () {
      // Con la mano pronada 60 grados la palma se ve la mitad de ancha, y la
      // pieza encoge en consecuencia.
      //
      // Se intento evitarlo con la reconstruccion metrica —primero por escala
      // absoluta, luego por proporciones— y las dos veces salio peor: medido en
      // dispositivo, el ancho metrico de la palma varia un 65% entre palma
      // arriba y palma abajo, cuando es una distancia 3D que no puede cambiar.
      // En esas mismas muestras el ancho en imagen solo variaba un 4%, porque
      // en ambas poses el plano de la palma queda casi paralelo a la camara.
      //
      // Asi que se prefiere la senal estable aunque no sea invariante: encoge
      // en poses de canto, que son ademas las que menos se usan para probarse
      // una pulsera.
      const cos60 = 0.5;
      const sin60 = 0.8660254037844387;
      Vec3 girar(Vec3 v) => Vec3(v.x * cos60, v.y, -v.x * sin60);

      final frontal = strategy.computeAnchor(
        proyectar(wristW, indexW, pinkyW, escala: 2.0),
      )!;
      final girada = BraceletStrategy().computeAnchor(
        proyectar(wristW, girar(indexW), girar(pinkyW), escala: 2.0),
      )!;

      expect(girada.scale!, closeTo(frontal.scale! * cos60, 1e-6));
    });

    test('la pieza cambia de tamano con la distancia', () {
      final lejos = strategy.computeAnchor(
        proyectar(wristW, indexW, pinkyW, escala: 1.5),
      )!;
      final cerca = BraceletStrategy().computeAnchor(
        proyectar(wristW, indexW, pinkyW, escala: 3.0),
      )!;

      expect(cerca.scale!, closeTo(lejos.scale! * 2, 1e-6));
    });
  });

  group('rechazo de detecciones malas', () {
    test('sin landmarks suficientes devuelve null', () {
      expect(strategy.computeAnchor(LandmarkFrame.empty), isNull);
      expect(
        strategy.computeAnchor(
          LandmarkFrame(landmarks: List.filled(10, const Landmark(0, 0, 0))),
        ),
        isNull,
      );
    });

    test('descarta manos demasiado pequenas en el encuadre', () {
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.505),
          indexMcp: (0.495, 0.5),
          pinkyMcp: (0.505, 0.5),
        ),
      );

      expect(anchor, isNull);
    });

    test('descarta la mano degenerada (palma y muneca en el mismo punto)', () {
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.4),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
        ),
      );

      expect(anchor, isNull);
    });
  });

}

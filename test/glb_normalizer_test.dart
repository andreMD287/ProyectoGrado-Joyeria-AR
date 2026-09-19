import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/core/assets/glb_normalizer.dart';

/// Arma un GLB minimo valido con el JSON dado y, opcionalmente, un trozo
/// binario. Replica lo que hace un exportador: cabecera, trozos y relleno a 4.
Uint8List buildGlb(Map<String, dynamic> json, {List<int>? bin}) {
  List<int> pad(List<int> d, int relleno) {
    final sobra = d.length % 4;
    return sobra == 0 ? d : [...d, ...List.filled(4 - sobra, relleno)];
  }

  final jsonBytes = pad(utf8.encode(jsonEncode(json)), 0x20);
  final binBytes = bin == null ? null : pad(bin, 0x00);

  final total =
      12 + 8 + jsonBytes.length + (binBytes == null ? 0 : 8 + binBytes.length);
  final out = Uint8List(total);
  final view = ByteData.sublistView(out);

  view.setUint32(0, 0x46546C67, Endian.little);
  view.setUint32(4, 2, Endian.little);
  view.setUint32(8, total, Endian.little);
  view.setUint32(12, jsonBytes.length, Endian.little);
  view.setUint32(16, 0x4E4F534A, Endian.little);
  out.setRange(20, 20 + jsonBytes.length, jsonBytes);

  if (binBytes != null) {
    final inicio = 20 + jsonBytes.length;
    view.setUint32(inicio, binBytes.length, Endian.little);
    view.setUint32(inicio + 4, 0x004E4942, Endian.little);
    out.setRange(inicio + 8, inicio + 8 + binBytes.length, binBytes);
  }
  return out;
}

/// Extrae el JSON de un GLB ya normalizado, tal como lo leeria el cargador.
Map<String, dynamic> readJson(Uint8List glb) {
  final view = ByteData.sublistView(glb);
  final len = view.getUint32(12, Endian.little);
  return jsonDecode(utf8.decode(Uint8List.sublistView(glb, 20, 20 + len)))
      as Map<String, dynamic>;
}

List<int>? readBin(Uint8List glb) {
  final view = ByteData.sublistView(glb);
  final jsonLen = view.getUint32(12, Endian.little);
  final inicio = 20 + jsonLen;
  if (inicio + 8 > glb.length) return null;
  final binLen = view.getUint32(inicio, Endian.little);
  return Uint8List.sublistView(glb, inicio + 8, inicio + 8 + binLen);
}

void main() {
  group('campos reales escritos como entero', () {
    test('specularFactor entero pasa a real', () {
      // Es el caso exacto que rompe a arete_perla y pulsera_perlas_basica.
      final glb = buildGlb({
        'asset': {'version': '2.0'},
        'materials': [
          {
            'extensions': {
              'KHR_materials_specular': {'specularFactor': 0},
            },
          },
        ],
      });

      final json = readJson(normalizeGlbForLoader(glb));
      final valor = json['materials'][0]['extensions']
          ['KHR_materials_specular']['specularFactor'];

      expect(valor, isA<double>());
      expect(valor, 0.0);
    });

    test('los indices de textura siguen siendo enteros', () {
      // Estan dentro de la misma extension: si se convirtieran, el cargador
      // fallaria por el motivo contrario.
      final glb = buildGlb({
        'asset': {'version': '2.0'},
        'materials': [
          {
            'extensions': {
              'KHR_materials_specular': {
                'specularFactor': 0,
                'specularTexture': {'index': 0, 'texCoord': 1},
              },
            },
          },
        ],
      });

      final ext = readJson(normalizeGlbForLoader(glb))['materials'][0]
          ['extensions']['KHR_materials_specular'];

      expect(ext['specularTexture']['index'], isA<int>());
      expect(ext['specularTexture']['texCoord'], isA<int>());
    });

    test('convierte tambien dentro de listas', () {
      final glb = buildGlb({
        'asset': {'version': '2.0'},
        'materials': [
          {
            'pbrMetallicRoughness': {
              'baseColorFactor': [1, 0, 0, 1],
            },
          },
        ],
      });

      final factor = readJson(normalizeGlbForLoader(glb))['materials'][0]
          ['pbrMetallicRoughness']['baseColorFactor'] as List;

      expect(factor.every((e) => e is double), isTrue);
      expect(factor, [1.0, 0.0, 0.0, 1.0]);
    });
  });

  group('integridad del archivo', () {
    test('el trozo binario se conserva byte a byte', () {
      final bin = List<int>.generate(50, (i) => i % 256);
      final glb = buildGlb({
        'asset': {'version': '2.0'},
        'materials': [
          {'pbrMetallicRoughness': {'metallicFactor': 1}},
        ],
      }, bin: bin);

      final salida = normalizeGlbForLoader(glb);
      // El relleno se cuenta aparte: interesa que los datos utiles no cambien.
      expect(readBin(salida)!.sublist(0, bin.length), bin);
    });

    test('la longitud declarada coincide con el archivo', () {
      final glb = buildGlb({
        'asset': {'version': '2.0'},
        'materials': [
          {'pbrMetallicRoughness': {'metallicFactor': 0}},
        ],
      }, bin: List<int>.filled(13, 7)); // longitud no alineada a 4

      final salida = normalizeGlbForLoader(glb);
      final total = ByteData.sublistView(salida).getUint32(8, Endian.little);

      expect(total, salida.length);
      expect(salida.length % 4, 0);
    });

    test('sin nada que corregir devuelve los bytes originales', () {
      final glb = buildGlb({
        'asset': {'version': '2.0'},
        'materials': [
          {'pbrMetallicRoughness': {'metallicFactor': 0.5}},
        ],
      });

      expect(normalizeGlbForLoader(glb), same(glb));
    });

    test('un archivo que no es GLB se devuelve intacto', () {
      // Un `.gltf` suelto es JSON plano, no empieza por 'glTF'.
      final noGlb = Uint8List.fromList(utf8.encode('{"asset":{}}'));
      expect(normalizeGlbForLoader(noGlb), same(noGlb));
    });
  });

  group('modelos reales del catalogo', () {
    // Los GLB viven en assets/models. Si faltan (checkout sin LFS) la prueba se
    // salta en vez de fallar: no es el codigo lo que estaria roto.
    final dir = Directory('assets/models');

    test('las dos piezas que rompian al cargador quedan corregidas', () {
      for (final nombre in ['arete_perla.glb', 'pulsera_perlas_basica.glb']) {
        final file = File('${dir.path}/$nombre');
        if (!file.existsSync()) continue;

        final salida = normalizeGlbForLoader(file.readAsBytesSync());
        final json = readJson(salida);

        for (final material in (json['materials'] as List? ?? [])) {
          final ext = (material as Map)['extensions'] as Map?;
          final specular = ext?['KHR_materials_specular'] as Map?;
          final factor = specular?['specularFactor'];
          if (factor != null) {
            expect(factor, isA<double>(), reason: nombre);
          }
        }
      }
    });

    test('los modelos que ya cargaban no se corrompen', () {
      for (final nombre in ['cartier.glb', 'collar-cadena-01.glb']) {
        final file = File('${dir.path}/$nombre');
        if (!file.existsSync()) continue;

        final original = file.readAsBytesSync();
        final salida = normalizeGlbForLoader(original);

        final total = ByteData.sublistView(salida).getUint32(8, Endian.little);
        expect(total, salida.length, reason: nombre);
        expect(readJson(salida)['asset'], isNotNull, reason: nombre);
      }
    });
  });
}

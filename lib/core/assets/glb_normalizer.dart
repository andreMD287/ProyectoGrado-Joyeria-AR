import 'dart:convert';
import 'dart:typed_data';

/// Ajusta un GLB para que el cargador de `three_js` pueda leerlo.
///
/// **El problema.** glTF define ciertos campos como número real, pero JSON no
/// distingue `0` de `0.0`: Blender exporta el cero como entero y el cargador
/// lo asigna a un campo tipado `double?`, que revienta con
/// `type 'int' is not a subtype of type 'double?'`. Afecta hoy a las piezas
/// con `KHR_materials_specular` (`arete_perla`, `pulsera_perlas_basica`), y
/// afectará a cualquier pieza futura exportada igual.
///
/// **Por qué aquí y no en el cargador.** Parchear `three_js` obligaría a
/// mantener un fork y un `dependency_overrides`; reexportar las piezas deja el
/// problema latente para la siguiente. Normalizar en memoria, en cambio, no
/// toca ni la dependencia ni los archivos del catálogo, y cubre las piezas que
/// aún no existen. El cargador se alimenta después con `fromBytes`.
///
/// Solo se tocan los valores numéricos de la lista blanca [_camposReales]; los
/// enteros que **deben** seguir siendo enteros (índices de textura, `texCoord`,
/// contadores) quedan intactos porque no están en ella.
Uint8List normalizeGlbForLoader(Uint8List bytes) {
  final glb = _GlbChunks.parse(bytes);
  // No es un GLB binario (p. ej. un `.gltf` suelto): se devuelve tal cual, que
  // es lo mismo que haría el cargador sin este paso.
  if (glb == null) return bytes;

  final json = jsonDecode(utf8.decode(glb.json)) as Map<String, dynamic>;
  if (!_coerceReales(json)) return bytes;

  return glb.rebuild(utf8.encode(jsonEncode(json)));
}

/// Campos que glTF define como número real. Un entero aquí es válido según
/// JSON pero rompe al cargador, así que se convierte.
const _camposReales = {
  // Material base (glTF 2.0 core).
  'metallicFactor', 'roughnessFactor', 'alphaCutoff', 'baseColorFactor',
  'emissiveFactor', 'strength',
  // KHR_materials_*
  'specularFactor', 'specularColorFactor', 'transmissionFactor', 'ior',
  'clearcoatFactor', 'clearcoatRoughnessFactor', 'thicknessFactor',
  'attenuationDistance', 'attenuationColor', 'emissiveStrength',
  'sheenColorFactor', 'sheenRoughnessFactor', 'iridescenceFactor',
  'iridescenceIor', 'iridescenceThicknessMinimum',
  'iridescenceThicknessMaximum', 'anisotropyStrength', 'anisotropyRotation',
  'dispersion',
};

/// Convierte a `double` los enteros que aparezcan en [_camposReales].
/// Devuelve `true` si cambió algo.
bool _coerceReales(Object? node) {
  var cambio = false;

  if (node is Map<String, dynamic>) {
    for (final entry in node.entries.toList()) {
      final value = entry.value;
      if (_camposReales.contains(entry.key)) {
        if (value is int) {
          node[entry.key] = value.toDouble();
          cambio = true;
          continue;
        }
        if (value is List && value.any((e) => e is int)) {
          node[entry.key] = [
            for (final e in value) e is num ? e.toDouble() : e,
          ];
          cambio = true;
          continue;
        }
      }
      if (_coerceReales(value)) cambio = true;
    }
  } else if (node is List) {
    for (final item in node) {
      if (_coerceReales(item)) cambio = true;
    }
  }

  return cambio;
}

/// Las tres partes de un GLB: cabecera de 12 bytes, trozo JSON y trozo binario.
/// Cada trozo se alinea a 4 bytes — el JSON con espacios y el binario con ceros.
class _GlbChunks {
  static const _magic = 0x46546C67; // 'glTF'
  static const _tipoJson = 0x4E4F534A;
  static const _tipoBin = 0x004E4942;

  final int version;
  final Uint8List json;
  final Uint8List? bin;

  const _GlbChunks({
    required this.version,
    required this.json,
    required this.bin,
  });

  static _GlbChunks? parse(Uint8List bytes) {
    if (bytes.length < 12) return null;
    final view = ByteData.sublistView(bytes);
    if (view.getUint32(0, Endian.little) != _magic) return null;

    final version = view.getUint32(4, Endian.little);
    Uint8List? json;
    Uint8List? bin;

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final length = view.getUint32(offset, Endian.little);
      final type = view.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      if (start + length > bytes.length) return null;

      final data = Uint8List.sublistView(bytes, start, start + length);
      if (type == _tipoJson) {
        json = data;
      } else if (type == _tipoBin) {
        bin = data;
      }
      offset = start + length;
    }

    if (json == null) return null;
    return _GlbChunks(version: version, json: json, bin: bin);
  }

  /// Rearma el archivo con un JSON nuevo, recalculando relleno y longitudes.
  Uint8List rebuild(List<int> nuevoJson) {
    final json = _pad(nuevoJson, 0x20); // espacios
    final binario = bin == null ? null : _pad(bin!, 0x00); // ceros

    final total = 12 +
        8 +
        json.length +
        (binario == null ? 0 : 8 + binario.length);

    final out = Uint8List(total);
    final view = ByteData.sublistView(out);

    view.setUint32(0, _magic, Endian.little);
    view.setUint32(4, version, Endian.little);
    view.setUint32(8, total, Endian.little);

    view.setUint32(12, json.length, Endian.little);
    view.setUint32(16, _tipoJson, Endian.little);
    out.setRange(20, 20 + json.length, json);

    if (binario != null) {
      final inicio = 20 + json.length;
      view.setUint32(inicio, binario.length, Endian.little);
      view.setUint32(inicio + 4, _tipoBin, Endian.little);
      out.setRange(inicio + 8, inicio + 8 + binario.length, binario);
    }

    return out;
  }

  static Uint8List _pad(List<int> data, int relleno) {
    final sobra = data.length % 4;
    if (sobra == 0) return Uint8List.fromList(data);
    return Uint8List.fromList([
      ...data,
      ...List.filled(4 - sobra, relleno),
    ]);
  }
}

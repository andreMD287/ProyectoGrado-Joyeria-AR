"""Reduce la resolución de las texturas incrustadas en un GLB.

Uso:
    python tool/reducir_texturas_glb.py entrada.glb salida.glb [--max 512]

Por qué: `three_js` decodifica las imágenes del GLB en Dart puro, y cada
textura de 2048x2048 cuesta del orden de 1,5-2 s en el Galaxy A15. Las piezas
de perla traían cinco cada una y tardaban 7-10 s en cargar (los aretes, el
doble: se carga un GLB por oreja), contra 0,07 s de los collares, que no
tienen texturas (medido el 2026-11-22). En pantalla un arete ocupa unos 60 px
y una pulsera unos 250 px, así que 512 px de textura sobran.

Qué hace: cada imagen con un lado mayor que --max se escala (Lanczos) para que
su lado mayor quede en --max, conservando la proporción y el formato (PNG sigue
PNG, JPEG sigue JPEG). Todo lo demás (geometría, materiales, extensiones) se
copia tal cual: solo se reconstruye el buffer binario con las imágenes nuevas y
se actualizan las posiciones de las bufferViews.

Requiere Pillow (pip install pillow).
"""

import argparse
import io
import json
import struct
import sys

from PIL import Image

GLB_MAGIC = 0x46546C67  # 'glTF'
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942


def leer_glb(datos: bytes):
    magic, version, _ = struct.unpack_from("<III", datos, 0)
    if magic != GLB_MAGIC or version != 2:
        raise ValueError("no es un GLB 2.0")
    pos = 12
    gltf, binario = None, b""
    while pos < len(datos):
        largo, tipo = struct.unpack_from("<II", datos, pos)
        cuerpo = datos[pos + 8 : pos + 8 + largo]
        if tipo == CHUNK_JSON:
            gltf = json.loads(cuerpo.decode("utf-8"))
        elif tipo == CHUNK_BIN:
            binario = cuerpo
        pos += 8 + largo
    if gltf is None:
        raise ValueError("GLB sin bloque JSON")
    return gltf, binario


def escribir_glb(gltf, binario: bytes) -> bytes:
    js = json.dumps(gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    js += b" " * (-len(js) % 4)
    binario += b"\0" * (-len(binario) % 4)
    total = 12 + 8 + len(js) + (8 + len(binario) if binario else 0)
    out = struct.pack("<III", GLB_MAGIC, 2, total)
    out += struct.pack("<II", len(js), CHUNK_JSON) + js
    if binario:
        out += struct.pack("<II", len(binario), CHUNK_BIN) + binario
    return out


def reducir(imagen: bytes, mime: str, maximo: int):
    im = Image.open(io.BytesIO(imagen))
    w, h = im.size
    if max(w, h) <= maximo:
        return imagen, (w, h), (w, h)
    escala = maximo / max(w, h)
    nuevo = (max(1, round(w * escala)), max(1, round(h * escala)))
    im = im.resize(nuevo, Image.LANCZOS)
    buf = io.BytesIO()
    if mime == "image/jpeg":
        im.convert("RGB").save(buf, "JPEG", quality=92, optimize=True)
    else:
        im.save(buf, "PNG", optimize=True)
    return buf.getvalue(), (w, h), nuevo


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("entrada")
    ap.add_argument("salida")
    ap.add_argument("--max", type=int, default=512, help="lado mayor en px")
    args = ap.parse_args()

    with open(args.entrada, "rb") as f:
        gltf, binario = leer_glb(f.read())
    if len(gltf.get("buffers", [])) > 1:
        sys.exit("solo se admite un buffer (el bloque BIN del GLB)")

    vistas = gltf.get("bufferViews", [])
    reemplazos = {}
    for i, img in enumerate(gltf.get("images", [])):
        if "bufferView" not in img:
            continue
        v = vistas[img["bufferView"]]
        ini = v.get("byteOffset", 0)
        original = binario[ini : ini + v["byteLength"]]
        mime = img.get("mimeType", "image/png")
        nuevo, antes, despues = reducir(original, mime, args.max)
        if nuevo is not original:
            reemplazos[img["bufferView"]] = nuevo
        print(f"imagen {i} ({mime}): {antes[0]}x{antes[1]} -> {despues[0]}x{despues[1]}, "
              f"{len(original) / 1e6:.2f} -> {len(nuevo) / 1e6:.2f} MB")

    # Se rearma el binario vista por vista, alineando cada una a 4 bytes.
    nuevo_bin = bytearray()
    for idx, v in enumerate(vistas):
        ini = v.get("byteOffset", 0)
        datos = reemplazos.get(idx, binario[ini : ini + v["byteLength"]])
        nuevo_bin += b"\0" * (-len(nuevo_bin) % 4)
        v["byteOffset"] = len(nuevo_bin)
        v["byteLength"] = len(datos)
        nuevo_bin += datos
    if gltf.get("buffers"):
        gltf["buffers"][0]["byteLength"] = len(nuevo_bin)

    salida = escribir_glb(gltf, bytes(nuevo_bin))
    with open(args.salida, "wb") as f:
        f.write(salida)
    print(f"{args.entrada}: {sum(1 for _ in reemplazos)} imagen(es) reducida(s), "
          f"{len(binario) / 1e6:.2f} -> {len(nuevo_bin) / 1e6:.2f} MB de binario")


if __name__ == "__main__":
    main()

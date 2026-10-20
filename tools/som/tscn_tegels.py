"""Lees/schrijf de tile_map_data van een TileMapLayer in een .tscn (Godot 4.3, formaat 0: per cel
int16 x, int16 y, uint16 bron, uint16 atlas-x, uint16 atlas-y, uint16 alternatief)."""
import re, base64, struct


def _match(src, laag):
    return re.search(r'(\[node name="%s"[^\n]*\]\ntile_map_data = PackedByteArray\(")([^"]*)("\))' % laag, src)


def lees(src, laag):
    b = base64.b64decode(_match(src, laag).group(2))
    cellen = {}
    for i in range(2, len(b), 12):
        x, y, s, ax, ay, al = struct.unpack('<hhHHHH', b[i:i + 12])
        cellen[(x, y)] = (s, ax, ay, al)
    return cellen


def schrijf(src, laag, cellen):
    b = bytearray(struct.pack('<H', 0))
    for (x, y) in sorted(cellen, key=lambda k: (k[1], k[0])):
        b += struct.pack('<hhHHHH', x, y, *cellen[(x, y)])
    m = _match(src, laag)
    return src[:m.start(2)] + base64.b64encode(bytes(b)).decode() + src[m.end(2):]


## Soort per tegel van assets/tiles/dorp.png (tools/generate_art.py + tools/art_maps.py).
def soort(i):
    if i in (0, 1, 8, 9, 10): return '.'
    if i == 3: return 'T'
    if i == 2 or 11 <= i <= 25: return '='
    if i == 5 or 26 <= i <= 32: return '~'
    if 33 <= i <= 48: return '#'
    return {49: 'H', 50: 'F', 51: 'M', 52: '*', 53: 'O', 7: 'R', 4: 'W', 6: 'D'}.get(i, '?')

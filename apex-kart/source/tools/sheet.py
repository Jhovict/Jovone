import json, sys
from PIL import Image, ImageDraw
raw = json.load(open('raw.json'))
tiles = []
for name, r in sorted(raw.items()):
    im = Image.open('../' + name).convert('RGB')
    d = ImageDraw.Draw(im)
    xy = [tuple(p) for p in r['xy']]
    d.line(xy + [xy[0]], fill=(255, 0, 0), width=3)
    d.ellipse([xy[0][0]-8, xy[0][1]-8, xy[0][0]+8, xy[0][1]+8], fill=(0, 255, 0))
    if r['arrow']:
        a = r['arrow']; d.ellipse([a[0]-8, a[1]-8, a[0]+8, a[1]+8], outline=(0, 200, 255), width=3)
    d.text((10, 10), name, fill=(255, 255, 0))
    im.thumbnail((500, 330))
    tiles.append(im)
W = 4
sheet = Image.new('RGB', (500 * W, 330 * ((len(tiles) + W - 1) // W)))
for k, t in enumerate(tiles):
    sheet.paste(t, ((k % W) * 500, (k // W) * 330))
sheet.save(sys.argv[1])

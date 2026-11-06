import json, sys
from PIL import Image, ImageDraw
tiles = []
idx = json.load(open('../apex_gp/tracks/index.json', encoding='utf-8'))
for t in idx:
    key = t['file'].split('/')[-1].split('.')[0]
    d = json.load(open('../apex_gp/tracks/%s.json' % key))
    s = d['scale']
    im = Image.open('../%s.jpg' % key).convert('RGB')
    im = im.point(lambda v: v * 0.45)
    dr = ImageDraw.Draw(im)
    pts = [(p[0] / s, p[1] / s) for p in d['pts']]
    dr.line(pts + [pts[0]], fill=(255, 40, 40), width=2)
    dr.text((10, 10), key + ' ' + d['name'], fill=(255, 255, 0))
    im.thumbnail((500, 330))
    tiles.append(im)
W = 4
sheet = Image.new('RGB', (500 * W, 330 * ((len(tiles) + W - 1) // W)))
for k, t in enumerate(tiles):
    sheet.paste(t, ((k % W) * 500, (k // W) * 330))
sheet.save(sys.argv[1])

"""Prepare app-icon assets from the source artwork.

The source JPG has a baked-in checkerboard "transparency" background.
- Flood-fills the neutral bright background from the corners (stops at the
  card's magenta/gold frame), then crops the card and rounds its corners.
- icon.png: full-bleed opaque 1024x1024 (edges stretched to fill).
- icon_foreground.png: transparent-padded card for Android adaptive icons.
"""

from collections import deque

from PIL import Image, ImageDraw

SRC = r"D:\Download\Gemini_Generated_Image_oyn77loyn77loyn7.jpg"
OUT_MAIN = r"C:\Users\Nazmul Hossain\OneDrive\Desktop\perfumes\assets\icon\icon.png"
OUT_FG = r"C:\Users\Nazmul Hossain\OneDrive\Desktop\perfumes\assets\icon\icon_foreground.png"
SIZE = 1024
CARD_FRAC = 0.86
MARKER = (255, 0, 255)


def is_neutral_bright(p):
    # dark gray checkerboard squares (~48 and ~98), neutral, not too dark
    r, g, b = p[:3]
    lo, hi = min(r, g, b), max(r, g, b)
    return 25 <= lo and hi <= 180 and (hi - lo) <= 30


def remove_checkerboard(im):
    """Flood fill from the borders over neutral-bright (checkerboard) pixels."""
    px = im.load()
    w, h = im.size
    mask = bytearray(w * h)  # 1 = background
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_neutral_bright(px[x, y]) and not mask[y * w + x]:
                mask[y * w + x] = 1
                queue.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_neutral_bright(px[x, y]) and not mask[y * w + x]:
                mask[y * w + x] = 1
                queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not mask[ny * w + nx]:
                if is_neutral_bright(px[nx, ny]):
                    mask[ny * w + nx] = 1
                    queue.append((nx, ny))
    return mask


def card_bbox(mask, w, h):
    xs, ys = [], []
    for y in range(h):
        row = y * w
        for x in range(w):
            if not mask[row + x]:
                xs.append(x)
                ys.append(y)
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def rounded_card(im, mask, bbox):
    """Crop with inset, drop trapped background pixels, round the corners."""
    inset = 10
    x0, y0, x1, y1 = bbox
    card = im.crop((x0 + inset, y0 + inset, x1 - inset, y1 - inset)).convert("RGBA")
    cw, ch = card.size

    # zero out any remaining neutral (checkerboard) pixels
    px = card.load()
    for y in range(ch):
        for x in range(cw):
            if is_neutral_bright(px[x, y]):
                p = px[x, y]
                px[x, y] = (p[0], p[1], p[2], 0)

    # detect corner radius from the flood-fill mask shape
    mw = len(mask) and int(len(mask) ** 0.5)
    def is_bg(x, y):
        return mask[y * mw + x] == 1

    r_y = 0
    scan_y = y0 + inset + 2
    for x in range(x0 + inset, x1 - inset):
        if not is_bg(x, scan_y):
            r_y = x - (x0 + inset)
            break
    r_x = 0
    scan_x = x0 + inset + 2
    for y in range(y0 + inset, y1 - inset):
        if not is_bg(scan_x, y):
            r_x = y - (y0 + inset)
            break
    radius = max(int((r_x + r_y) / 2), 40)

    round_mask = Image.new("L", (cw, ch), 0)
    ImageDraw.Draw(round_mask).rounded_rectangle(
        (0, 0, cw - 1, ch - 1), radius=radius, fill=255
    )
    alpha = card.getchannel("A")
    from PIL import ImageChops
    card.putalpha(ImageChops.multiply(alpha, round_mask))
    return card


def edge_stretch_fill(canvas, card, offset):
    """Fill the margins around [card] by stretching its edge pixels."""
    cw, ch = card.size
    ox, oy = offset
    # left / right (sample a few px inside so transparent corners are avoided)
    pad = 4
    lw = ox
    if lw > 0:
        strip = card.crop((pad, 0, pad + 1, ch)).resize((lw, ch))
        canvas.paste(strip, (0, oy), strip)
    rw = canvas.width - ox - cw
    if rw > 0:
        strip = card.crop((cw - pad - 1, 0, cw - pad, ch)).resize((rw, ch))
        canvas.paste(strip, (ox + cw, oy), strip)
    # top / bottom across the full width
    th = oy
    if th > 0:
        strip = canvas.crop((0, oy + pad, canvas.width, oy + pad + 1)).resize(
            (canvas.width, th)
        )
        canvas.paste(strip, (0, 0))
    bh = canvas.height - oy - ch
    if bh > 0:
        strip = canvas.crop(
            (0, oy + ch - pad - 1, canvas.width, oy + ch - pad)
        ).resize((canvas.width, bh))
        canvas.paste(strip, (0, oy + ch))


def main():
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    print(f"source {im.size}")

    mask = remove_checkerboard(im)
    bbox = card_bbox(mask, w, h)
    print(f"card bbox {bbox} size {(bbox[2]-bbox[0], bbox[3]-bbox[1])}")

    card = rounded_card(im, mask, bbox)
    cw, ch = card.size

    # full-bleed opaque icon: cover the square, stretch edges into margins
    scale = max(SIZE / cw, SIZE / ch)
    resized = card.resize((round(cw * scale), round(ch * scale)), Image.LANCZOS)
    base = resized.getpixel((resized.width // 2, 2))  # top edge tone
    canvas = Image.new("RGBA", (SIZE, SIZE), base[:3] + (255,))
    ox, oy = (SIZE - resized.width) // 2, (SIZE - resized.height) // 2
    canvas.paste(resized, (ox, oy), resized)
    edge_stretch_fill(canvas, resized, (ox, oy))
    canvas.convert("RGB").save(OUT_MAIN)

    # adaptive foreground: transparent padding around the card
    target = round(SIZE * CARD_FRAC)
    scale = target / max(cw, ch)
    resized = card.resize((round(cw * scale), round(ch * scale)), Image.LANCZOS)
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fg.paste(
        resized,
        ((SIZE - resized.width) // 2, (SIZE - resized.height) // 2),
        resized,
    )
    fg.save(OUT_FG)

    print(f"saved {OUT_MAIN}")
    print(f"saved {OUT_FG}")


if __name__ == "__main__":
    main()

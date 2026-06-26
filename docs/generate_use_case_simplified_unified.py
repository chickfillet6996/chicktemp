from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "chicktemp_use_case_simplified_unified.png"

WIDTH = 1500
HEIGHT = 1850

WHITE = "#ffffff"
PAPER = "#fbfbfb"
TEXT = "#242424"
MUTED = "#666666"
BORDER = "#a8a8a8"
DARK = "#333333"
USECASE_FILL = "#fff4dd"
USECASE_BORDER = "#c8a15a"
ACTOR_FILL = "#ffffff"
EXTERNAL_FILL = "#eef3f8"


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    candidates = {
        "regular": [
            r"C:\Windows\Fonts\arial.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        ],
        "bold": [
            r"C:\Windows\Fonts\arialbd.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        ],
    }
    for candidate in candidates[name]:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


F_TITLE = font("bold", 34)
F_SUBTITLE = font("regular", 22)
F_LABEL = font("bold", 23)
F_SMALL = font("regular", 18)
F_ACTOR = font("bold", 21)


def text_size(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont) -> tuple[int, int]:
    left, top, right, bottom = draw.textbbox((0, 0), text, font=fnt)
    return right - left, bottom - top


def wrap_text(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = word if not current else f"{current} {word}"
        if text_size(draw, candidate, fnt)[0] <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_centered(draw: ImageDraw.ImageDraw, center: tuple[int, int], text: str, fnt, fill: str, max_width: int) -> None:
    lines = wrap_text(draw, text, fnt, max_width)
    line_h = fnt.getbbox("Ag")[3] - fnt.getbbox("Ag")[1] + 7
    total_h = line_h * len(lines)
    y = center[1] - total_h / 2
    for line in lines:
        tw, _ = text_size(draw, line, fnt)
        draw.text((center[0] - tw / 2, y), line, font=fnt, fill=fill)
        y += line_h


def draw_ellipse_usecase(draw: ImageDraw.ImageDraw, cx: int, cy: int, w: int, h: int, label: str) -> tuple[int, int, int, int]:
    box = (cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2)
    draw.ellipse(box, fill=USECASE_FILL, outline=USECASE_BORDER, width=3)
    draw_centered(draw, (cx, cy), label, F_LABEL, TEXT, w - 42)
    return box


def draw_actor(draw: ImageDraw.ImageDraw, cx: int, cy: int, label: str) -> tuple[int, int, int, int]:
    head_r = 25
    draw.ellipse((cx - head_r, cy - 105, cx + head_r, cy - 55), fill=ACTOR_FILL, outline=DARK, width=3)
    draw.line((cx, cy - 55, cx, cy + 30), fill=DARK, width=4)
    draw.line((cx - 55, cy - 18, cx + 55, cy - 18), fill=DARK, width=4)
    draw.line((cx, cy + 30, cx - 50, cy + 95), fill=DARK, width=4)
    draw.line((cx, cy + 30, cx + 50, cy + 95), fill=DARK, width=4)
    draw_centered(draw, (cx, cy + 135), label, F_ACTOR, TEXT, 190)
    return cx - 80, cy - 110, cx + 80, cy + 165


def draw_external_actor(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, h: int, label: str) -> tuple[int, int, int, int]:
    draw.rounded_rectangle((x, y, x + w, y + h), radius=18, fill=EXTERNAL_FILL, outline=BORDER, width=3)
    draw_centered(draw, (x + w // 2, y + h // 2), label, F_ACTOR, TEXT, w - 35)
    return x, y, x + w, y + h


def point_on_ellipse(cx: int, cy: int, w: int, h: int, target: tuple[int, int]) -> tuple[int, int]:
    tx, ty = target
    dx = tx - cx
    dy = ty - cy
    if dx == 0 and dy == 0:
        return cx, cy
    scale = 1 / math.sqrt((dx / (w / 2)) ** 2 + (dy / (h / 2)) ** 2)
    return int(cx + dx * scale), int(cy + dy * scale)


def line(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int]) -> None:
    draw.line((start[0], start[1], end[0], end[1]), fill=MUTED, width=3)


def main() -> None:
    image = Image.new("RGB", (WIDTH, HEIGHT), WHITE)
    draw = ImageDraw.Draw(image)

    draw.rectangle((24, 24, WIDTH - 24, HEIGHT - 24), outline=DARK, width=3)
    title = "CHICKTEMP FARM MANAGEMENT MOBILE APP"
    subtitle = "Simplified User Interaction Model (Use Case Diagram)"
    tw, th = text_size(draw, title, F_TITLE)
    draw.text(((WIDTH - tw) / 2, 45), title, font=F_TITLE, fill=TEXT)
    sw, sh = text_size(draw, subtitle, F_SUBTITLE)
    draw.text(((WIDTH - sw) / 2, 84), subtitle, font=F_SUBTITLE, fill=MUTED)

    system_box = (380, 165, 1120, 1710)
    draw.rounded_rectangle(system_box, radius=24, fill=PAPER, outline=BORDER, width=3)
    system_label = "ChickTemp Mobile Application"
    lw, _ = text_size(draw, system_label, F_LABEL)
    draw.text((system_box[0] + (system_box[2] - system_box[0] - lw) / 2, 174), system_label, font=F_LABEL, fill=TEXT)

    actor_box = draw_actor(draw, 180, 930, "Farm Manager / User")

    usecases = [
        ("Create / Login Account", 750, 330),
        ("Manage Profile", 750, 500),
        ("View Dashboard & Monitoring", 750, 670),
        ("Manage Poultry Batches", 750, 840),
        ("Control Devices", 750, 1010),
        ("Manage Alerts", 750, 1180),
        ("View Reports & Analytics", 750, 1350),
        ("Access Support", 750, 1520),
    ]

    usecase_boxes: dict[str, tuple[int, int, int, int]] = {}
    oval_w = 470
    oval_h = 105
    for label, cx, cy in usecases:
        usecase_boxes[label] = draw_ellipse_usecase(draw, cx, cy, oval_w, oval_h, label)

    actor_anchor = (actor_box[2], (actor_box[1] + actor_box[3]) // 2)
    bus_x = 340
    min_y = min(cy for _, _, cy in usecases)
    max_y = max(cy for _, _, cy in usecases)
    line(draw, actor_anchor, (bus_x, actor_anchor[1]))
    line(draw, (bus_x, min_y), (bus_x, max_y))
    for label, cx, cy in usecases:
        target = point_on_ellipse(cx, cy, oval_w, oval_h, (bus_x, cy))
        line(draw, (bus_x, cy), target)

    note = "Only the main user actions are shown to keep the diagram simple and readable."
    nw, _ = text_size(draw, note, F_SMALL)
    draw.text(((WIDTH - nw) / 2, HEIGHT - 78), note, font=F_SMALL, fill=MUTED)

    image.save(OUT)
    print(OUT)
    print(f"{WIDTH}x{HEIGHT}")


if __name__ == "__main__":
    main()

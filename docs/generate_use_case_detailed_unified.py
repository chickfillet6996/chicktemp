from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "chicktemp_use_case_detailed_unified.png"

WIDTH = 2000
HEIGHT = 1900

WHITE = "#ffffff"
PAPER = "#fbfbfb"
TEXT = "#242424"
MUTED = "#666666"
BORDER = "#aaaaaa"
DARK = "#333333"
MAIN_FILL = "#fff1d8"
DETAIL_FILL = "#fffaf0"
USECASE_BORDER = "#c99a49"
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


F_TITLE = font("bold", 42)
F_SUBTITLE = font("regular", 25)
F_SYSTEM = font("bold", 30)
F_MAIN = font("bold", 24)
F_DETAIL = font("regular", 21)
F_LABEL = font("regular", 16)
F_ACTOR = font("bold", 22)


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


def draw_centered(
    draw: ImageDraw.ImageDraw,
    center: tuple[int, int],
    text: str,
    fnt: ImageFont.ImageFont,
    fill: str,
    max_width: int,
) -> None:
    lines = wrap_text(draw, text, fnt, max_width)
    line_h = fnt.getbbox("Ag")[3] - fnt.getbbox("Ag")[1] + 7
    y = center[1] - (len(lines) * line_h) / 2
    for line in lines:
        tw, _ = text_size(draw, line, fnt)
        draw.text((center[0] - tw / 2, y), line, font=fnt, fill=fill)
        y += line_h


def draw_usecase(
    draw: ImageDraw.ImageDraw,
    cx: int,
    cy: int,
    w: int,
    h: int,
    label: str,
    main: bool = False,
) -> tuple[int, int, int, int]:
    fill = MAIN_FILL if main else DETAIL_FILL
    box = (cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2)
    draw.ellipse(box, fill=fill, outline=USECASE_BORDER, width=3 if main else 2)
    draw_centered(draw, (cx, cy), label, F_MAIN if main else F_DETAIL, TEXT, w - 40)
    return box


def draw_actor(draw: ImageDraw.ImageDraw, cx: int, cy: int, label: str) -> tuple[int, int, int, int]:
    head_r = 28
    draw.ellipse((cx - head_r, cy - 115, cx + head_r, cy - 59), fill=WHITE, outline=DARK, width=4)
    draw.line((cx, cy - 59, cx, cy + 35), fill=DARK, width=4)
    draw.line((cx - 62, cy - 20, cx + 62, cy - 20), fill=DARK, width=4)
    draw.line((cx, cy + 35, cx - 58, cy + 108), fill=DARK, width=4)
    draw.line((cx, cy + 35, cx + 58, cy + 108), fill=DARK, width=4)
    draw_centered(draw, (cx, cy + 156), label, F_ACTOR, TEXT, 230)
    return cx - 90, cy - 120, cx + 90, cy + 185


def point_on_ellipse(cx: int, cy: int, w: int, h: int, target: tuple[int, int]) -> tuple[int, int]:
    tx, ty = target
    dx = tx - cx
    dy = ty - cy
    if dx == 0 and dy == 0:
        return cx, cy
    scale = 1 / math.sqrt((dx / (w / 2)) ** 2 + (dy / (h / 2)) ** 2)
    return int(cx + dx * scale), int(cy + dy * scale)


def solid_line(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], width: int = 3) -> None:
    draw.line((start[0], start[1], end[0], end[1]), fill=MUTED, width=width)


def dashed_line(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], dash: int = 12, gap: int = 9) -> None:
    sx, sy = start
    ex, ey = end
    dx = ex - sx
    dy = ey - sy
    dist = math.hypot(dx, dy)
    if dist == 0:
        return
    ux = dx / dist
    uy = dy / dist
    current = 0
    while current < dist:
        end_dash = min(current + dash, dist)
        draw.line(
            (
                sx + ux * current,
                sy + uy * current,
                sx + ux * end_dash,
                sy + uy * end_dash,
            ),
            fill=MUTED,
            width=2,
        )
        current += dash + gap


def label_on_line(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], text: str) -> None:
    mx = (start[0] + end[0]) / 2
    my = (start[1] + end[1]) / 2
    tw, th = text_size(draw, text, F_LABEL)
    pad = 5
    draw.rounded_rectangle(
        (mx - tw / 2 - pad, my - th / 2 - pad, mx + tw / 2 + pad, my + th / 2 + pad),
        radius=5,
        fill=WHITE,
        outline="#dddddd",
        width=1,
    )
    draw.text((mx - tw / 2, my - th / 2 - 1), text, font=F_LABEL, fill=MUTED)


def draw_external(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, h: int, label: str) -> tuple[int, int, int, int]:
    draw.rounded_rectangle((x, y, x + w, y + h), radius=18, fill=EXTERNAL_FILL, outline=BORDER, width=3)
    draw_centered(draw, (x + w // 2, y + h // 2), label, F_ACTOR, TEXT, w - 35)
    return x, y, x + w, y + h


def mid_left(box: tuple[int, int, int, int]) -> tuple[int, int]:
    return box[0], (box[1] + box[3]) // 2


def mid_right(box: tuple[int, int, int, int]) -> tuple[int, int]:
    return box[2], (box[1] + box[3]) // 2


def main() -> None:
    image = Image.new("RGB", (WIDTH, HEIGHT), WHITE)
    draw = ImageDraw.Draw(image)

    draw.rectangle((26, 26, WIDTH - 26, HEIGHT - 26), outline=DARK, width=3)
    title = "CHICKTEMP FARM MANAGEMENT MOBILE APP"
    subtitle = "Detailed Unified User Interaction Model (Use Case Diagram)"
    tw, _ = text_size(draw, title, F_TITLE)
    draw.text(((WIDTH - tw) / 2, 48), title, font=F_TITLE, fill=TEXT)
    sw, _ = text_size(draw, subtitle, F_SUBTITLE)
    draw.text(((WIDTH - sw) / 2, 96), subtitle, font=F_SUBTITLE, fill=MUTED)

    system = (360, 170, 1675, 1755)
    draw.rounded_rectangle(system, radius=28, fill=PAPER, outline=BORDER, width=3)
    system_label = "ChickTemp Mobile Application"
    lw, _ = text_size(draw, system_label, F_SYSTEM)
    draw.text((system[0] + (system[2] - system[0] - lw) / 2, 202), system_label, font=F_SYSTEM, fill=TEXT)

    actor_box = draw_actor(draw, 175, 1000, "Farm Manager / User")

    groups = [
        (
            "Account Management",
            370,
            ["Create Account", "Login", "Manage Profile", "Change Password"],
        ),
        (
            "Dashboard & Monitoring",
            630,
            ["View Dashboard", "Monitor Temperature", "Monitor Humidity", "Monitor Water & Feed Level", "View Daily Logs"],
        ),
        (
            "Device Control",
            890,
            ["Control Fan", "Control Water Pump", "Control Feeder", "Control Light", "Set Automation Rules"],
        ),
        (
            "Poultry Batch Management",
            1150,
            ["Create / Edit Batch", "Record Mortality", "View Batch History", "Analyze Survival Rate"],
        ),
        (
            "Reports, Alerts & Support",
            1450,
            ["View Reports", "View Analytics", "Receive Alerts", "Set Alert Preferences", "Contact Support"],
        ),
    ]

    main_x = 710
    detail_x_1 = 1210
    detail_x_2 = 1490
    main_w = 395
    main_h = 104
    detail_w = 270
    detail_h = 78
    main_boxes: list[tuple[int, int, int, int]] = []
    named_boxes: dict[str, tuple[int, int, int, int]] = {}

    bus_x = 320
    solid_line(draw, (actor_box[2], 1260), (bus_x, 1260), width=3)
    solid_line(draw, (bus_x, groups[0][1]), (bus_x, groups[-1][1]), width=3)

    for group_title, y, details in groups:
        main_box = draw_usecase(draw, main_x, y, main_w, main_h, group_title, main=True)
        main_boxes.append(main_box)
        named_boxes[group_title] = main_box
        solid_line(draw, (bus_x, y), point_on_ellipse(main_x, y, main_w, main_h, (bus_x, y)), width=3)

        for i, detail in enumerate(details):
            col_x = detail_x_1 if i % 2 == 0 else detail_x_2
            row = i // 2
            detail_y = y - 58 + row * 84
            dbox = draw_usecase(draw, col_x, detail_y, detail_w, detail_h, detail, main=False)
            named_boxes[detail] = dbox
            start = point_on_ellipse(main_x, y, main_w, main_h, (col_x, detail_y))
            end = point_on_ellipse(col_x, detail_y, detail_w, detail_h, (main_x, y))
            dashed_line(draw, start, end)
            if i == 0:
                label_on_line(draw, start, end, "<<include>>")

    note = "Main use cases are connected to the user; smaller use cases show the included actions inside each feature."
    nw, _ = text_size(draw, note, F_LABEL)
    draw.text(((WIDTH - nw) / 2, HEIGHT - 70), note, font=F_LABEL, fill=MUTED)

    image.save(OUT)
    print(OUT)
    print(f"{WIDTH}x{HEIGHT}")


if __name__ == "__main__":
    main()

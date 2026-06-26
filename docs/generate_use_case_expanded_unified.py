from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "chicktemp_use_case_expanded_unified.png"

WIDTH = 2600
HEIGHT = 3200

WHITE = "#ffffff"
PAPER = "#fbfbfb"
TEXT = "#242424"
MUTED = "#666666"
BORDER = "#aaaaaa"
DARK = "#333333"
MAIN_FILL = "#fff1d8"
DETAIL_FILL = "#fffaf0"
USECASE_BORDER = "#c99a49"


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


F_TITLE = font("bold", 48)
F_SUBTITLE = font("regular", 28)
F_SYSTEM = font("bold", 34)
F_MAIN = font("bold", 25)
F_DETAIL = font("regular", 21)
F_LABEL = font("regular", 17)
F_ACTOR = font("bold", 24)


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
    box = (cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2)
    draw.ellipse(box, fill=MAIN_FILL if main else DETAIL_FILL, outline=USECASE_BORDER, width=3 if main else 2)
    draw_centered(draw, (cx, cy), label, F_MAIN if main else F_DETAIL, TEXT, w - 36)
    return box


def draw_actor(draw: ImageDraw.ImageDraw, cx: int, cy: int, label: str) -> tuple[int, int, int, int]:
    head_r = 32
    draw.ellipse((cx - head_r, cy - 130, cx + head_r, cy - 66), fill=WHITE, outline=DARK, width=4)
    draw.line((cx, cy - 66, cx, cy + 42), fill=DARK, width=5)
    draw.line((cx - 70, cy - 20, cx + 70, cy - 20), fill=DARK, width=5)
    draw.line((cx, cy + 42, cx - 66, cy + 126), fill=DARK, width=5)
    draw.line((cx, cy + 42, cx + 66, cy + 126), fill=DARK, width=5)
    draw_centered(draw, (cx, cy + 185), label, F_ACTOR, TEXT, 260)
    return cx - 95, cy - 135, cx + 95, cy + 220


def solid_line(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], width: int = 3) -> None:
    draw.line((start[0], start[1], end[0], end[1]), fill=MUTED, width=width)


def dashed_line(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], dash: int = 13, gap: int = 9) -> None:
    sx, sy = start
    ex, ey = end
    dx = ex - sx
    dy = ey - sy
    dist = (dx * dx + dy * dy) ** 0.5
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


def label_box(draw: ImageDraw.ImageDraw, center: tuple[int, int], text: str) -> None:
    tw, th = text_size(draw, text, F_LABEL)
    pad_x = 8
    pad_y = 5
    x, y = center
    draw.rounded_rectangle(
        (x - tw / 2 - pad_x, y - th / 2 - pad_y, x + tw / 2 + pad_x, y + th / 2 + pad_y),
        radius=5,
        fill=WHITE,
        outline="#dddddd",
        width=1,
    )
    draw.text((x - tw / 2, y - th / 2 - 1), text, font=F_LABEL, fill=MUTED)


def main() -> None:
    image = Image.new("RGB", (WIDTH, HEIGHT), WHITE)
    draw = ImageDraw.Draw(image)

    draw.rectangle((28, 28, WIDTH - 28, HEIGHT - 28), outline=DARK, width=3)
    title = "CHICKTEMP FARM MANAGEMENT MOBILE APP"
    subtitle = "Expanded Unified User Interaction Model (Use Case Diagram)"
    tw, _ = text_size(draw, title, F_TITLE)
    draw.text(((WIDTH - tw) / 2, 52), title, font=F_TITLE, fill=TEXT)
    sw, _ = text_size(draw, subtitle, F_SUBTITLE)
    draw.text(((WIDTH - sw) / 2, 108), subtitle, font=F_SUBTITLE, fill=MUTED)

    system = (390, 180, 2460, 3035)
    draw.rounded_rectangle(system, radius=32, fill=PAPER, outline=BORDER, width=3)
    system_label = "ChickTemp Mobile Application"
    lw, _ = text_size(draw, system_label, F_SYSTEM)
    draw.text((system[0] + (system[2] - system[0] - lw) / 2, 218), system_label, font=F_SYSTEM, fill=TEXT)

    actor = draw_actor(draw, 190, 1630, "Farm Manager / User")

    groups = [
        (
            "Account & Security",
            430,
            [
                "Create Account",
                "Login",
                "Remember Login",
                "Reset Password",
                "Manage Profile",
                "Update Personal Details",
                "Change Password",
                "Logout",
            ],
        ),
        (
            "Dashboard & Monitoring",
            850,
            [
                "View Dashboard",
                "View Batch Dashboard",
                "View Real-Time Data",
                "Monitor Temperature",
                "Monitor Humidity",
                "Monitor Water Level",
                "Monitor Feed Level",
                "View Daily Logs",
            ],
        ),
        (
            "Device Control & Automation",
            1270,
            [
                "Control Ventilation Fan",
                "Control Water Pump",
                "Control Feeder",
                "Control Light",
                "Manage Feeding Schedule",
                "Manage Water Schedule",
                "Manage Lighting Schedule",
                "Set Sensor Thresholds",
                "Configure Automation Rules",
            ],
        ),
        (
            "Poultry Batch & Records",
            1690,
            [
                "Create Batch",
                "Edit Batch Details",
                "Delete Batch",
                "Update Grow-Out Day",
                "Record Mortality",
                "View Mortality History",
                "Add Event Report",
                "Add Maintenance Report",
                "Manage Devices",
            ],
        ),
        (
            "Reports & Analytics",
            2110,
            [
                "View Reports",
                "View Environmental History",
                "Compare Batch Reports",
                "View Analytics",
                "View Temperature Trends",
                "View Humidity Trends",
                "Analyze Mortality Rate",
                "View Survival Rate",
            ],
        ),
        (
            "Alerts, Preferences & Support",
            2530,
            [
                "Receive Critical Alerts",
                "View Alert List",
                "Set Alert Preferences",
                "Configure Notification Rules",
                "Manage App Preferences",
                "Access Support Services",
                "Contact Customer Support",
                "View Help Center & Policies",
            ],
        ),
    ]

    main_x = 720
    main_w = 420
    main_h = 100
    detail_w = 300
    detail_h = 72
    detail_xs = [1210, 1570, 1930]
    row_gap = 86
    main_to_hub_x = 980
    bus_x = 345

    solid_line(draw, (actor[2], 1630), (bus_x, 1630), width=3)
    solid_line(draw, (bus_x, groups[0][1]), (bus_x, groups[-1][1]), width=3)

    for title_text, y, details in groups:
        draw_usecase(draw, main_x, y, main_w, main_h, title_text, main=True)
        solid_line(draw, (bus_x, y), (main_x - main_w // 2, y), width=3)

        hub_top = y - 95
        hub_bottom = y + 95
        dashed_line(draw, (main_x + main_w // 2, y), (main_to_hub_x, y))
        dashed_line(draw, (main_to_hub_x, hub_top), (main_to_hub_x, hub_bottom))
        label_box(draw, ((main_x + main_w // 2 + main_to_hub_x) // 2, y - 24), "<<include>>")

        for i, detail in enumerate(details):
            col = i % 3
            row = i // 3
            dx = detail_xs[col]
            dy = y - 92 + row * row_gap
            draw_usecase(draw, dx, dy, detail_w, detail_h, detail)
            if col == 0:
                dashed_line(draw, (main_to_hub_x, dy), (dx - detail_w // 2, dy))

    note = "Expanded view shows the major features and their included actions while keeping all use cases inside one application boundary."
    nw, _ = text_size(draw, note, F_LABEL)
    draw.text(((WIDTH - nw) / 2, HEIGHT - 78), note, font=F_LABEL, fill=MUTED)

    image.save(OUT)
    print(OUT)
    print(f"{WIDTH}x{HEIGHT}")


if __name__ == "__main__":
    main()

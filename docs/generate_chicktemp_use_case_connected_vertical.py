from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "chicktemp_use_case_connected_vertical.png"

WIDTH = 1700
HEIGHT = 2600

WHITE = "#ffffff"
TEXT = "#222222"
MUTED = "#666666"
BORDER = "#444444"
USER = "#3867d6"
DEVICE = "#d94848"
SUPPORT = "#3a9d5d"
USECASE_FILL = "#fffdf7"
USECASE_BORDER = "#222222"


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


F_TITLE = font("bold", 36)
F_SUB = font("regular", 22)
F_USECASE = font("regular", 19)
F_SMALL = font("regular", 15)
F_ACTOR = font("bold", 18)


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
            continue
        if current:
            lines.append(current)
        current = word
    if current:
        lines.append(current)
    return lines


def centered_text(
    draw: ImageDraw.ImageDraw,
    center: tuple[int, int],
    text: str,
    fnt: ImageFont.ImageFont,
    fill: str = TEXT,
    max_width: int = 200,
) -> None:
    lines = wrap_text(draw, text, fnt, max_width)
    line_h = fnt.getbbox("Ag")[3] - fnt.getbbox("Ag")[1] + 5
    y = center[1] - (line_h * len(lines)) / 2
    for line in lines:
        tw, _ = text_size(draw, line, fnt)
        draw.text((center[0] - tw / 2, y), line, font=fnt, fill=fill)
        y += line_h


def actor(draw: ImageDraw.ImageDraw, x: int, y: int, label: str, color: str) -> None:
    r = 28
    draw.ellipse((x - r, y - 120, x + r, y - 64), outline=color, width=4)
    draw.line((x, y - 64, x, y + 35), fill=color, width=4)
    draw.line((x - 60, y - 24, x + 60, y - 24), fill=color, width=4)
    draw.line((x, y + 35, x - 55, y + 120), fill=color, width=4)
    draw.line((x, y + 35, x + 55, y + 120), fill=color, width=4)
    centered_text(draw, (x, y + 168), label, F_ACTOR, TEXT, 210)


def usecase(draw: ImageDraw.ImageDraw, x: int, y: int, text: str, w: int = 260, h: int = 70) -> tuple[int, int, int, int]:
    box = (x - w // 2, y - h // 2, x + w // 2, y + h // 2)
    draw.ellipse(box, fill=USECASE_FILL, outline=USECASE_BORDER, width=2)
    centered_text(draw, (x, y), text, F_USECASE, TEXT, w - 34)
    return box


def arrow_head(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], color: str) -> None:
    sx, sy = start
    ex, ey = end
    angle = math.atan2(ey - sy, ex - sx)
    size = 12
    a1 = angle + math.pi * 0.82
    a2 = angle - math.pi * 0.82
    p1 = (ex + size * math.cos(a1), ey + size * math.sin(a1))
    p2 = (ex + size * math.cos(a2), ey + size * math.sin(a2))
    draw.polygon([end, p1, p2], fill=color)


def line(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], color: str, width: int = 2, arrow: bool = False) -> None:
    draw.line((start, end), fill=color, width=width)
    if arrow:
        arrow_head(draw, start, end, color)


def dashed(
    draw: ImageDraw.ImageDraw,
    start: tuple[int, int],
    end: tuple[int, int],
    color: str = MUTED,
    width: int = 2,
    arrow: bool = True,
    label: str | None = None,
) -> None:
    sx, sy = start
    ex, ey = end
    dx = ex - sx
    dy = ey - sy
    dist = (dx * dx + dy * dy) ** 0.5
    if dist == 0:
        return
    ux = dx / dist
    uy = dy / dist
    pos = 0
    dash_len = 12
    gap = 8
    while pos < dist:
        end_pos = min(pos + dash_len, dist)
        draw.line(
            (
                sx + ux * pos,
                sy + uy * pos,
                sx + ux * end_pos,
                sy + uy * end_pos,
            ),
            fill=color,
            width=width,
        )
        pos += dash_len + gap
    if arrow:
        arrow_head(draw, start, end, color)
    if label:
        mx = (sx + ex) / 2
        my = (sy + ey) / 2
        tw, th = text_size(draw, label, F_SMALL)
        draw.rounded_rectangle((mx - tw / 2 - 5, my - th / 2 - 4, mx + tw / 2 + 5, my + th / 2 + 4), 4, fill=WHITE, outline="#dddddd")
        draw.text((mx - tw / 2, my - th / 2 - 1), label, font=F_SMALL, fill=MUTED)


def main() -> None:
    image = Image.new("RGB", (WIDTH, HEIGHT), WHITE)
    draw = ImageDraw.Draw(image)

    draw.rectangle((22, 22, WIDTH - 22, HEIGHT - 22), outline=BORDER, width=3)
    title = "CHICKTEMP FARM MANAGEMENT MOBILE APP"
    subtitle = "Connected Use Case Diagram"
    tw, _ = text_size(draw, title, F_TITLE)
    sw, _ = text_size(draw, subtitle, F_SUB)
    draw.text(((WIDTH - tw) / 2, 52), title, font=F_TITLE, fill=TEXT)
    draw.text(((WIDTH - sw) / 2, 94), subtitle, font=F_SUB, fill=MUTED)

    boundary = (300, 150, 1395, 2460)
    draw.rounded_rectangle(boundary, radius=8, outline=BORDER, width=2)
    app_label = "ChickTemp Mobile Application"
    aw, _ = text_size(draw, app_label, F_SUB)
    draw.text((boundary[0] + (boundary[2] - boundary[0] - aw) / 2, 172), app_label, font=F_SUB, fill=TEXT)

    actor(draw, 150, 1260, "Farm Manager / User", USER)
    actor(draw, 1535, 895, "ESP32 / Hardware System", DEVICE)
    actor(draw, 1535, 2100, "Support Email Service", SUPPORT)

    # Use case positions
    positions = {
        "Create Account": (520, 280),
        "Login": (850, 280),
        "Remember Login": (1180, 280),
        "Manage Profile": (520, 380),
        "Update Personal Details": (850, 380),
        "Change Password": (1180, 380),
        "Logout": (850, 480),
        "View Dashboard": (520, 640),
        "View Batch Dashboard": (850, 640),
        "View Real-Time Sensor Data": (1180, 640),
        "Monitor Temperature": (520, 750),
        "Monitor Humidity": (850, 750),
        "Monitor Water Level": (1180, 750),
        "Monitor Feed Level": (1180, 850),
        "Receive Critical Alerts": (520, 900),
        "Manage Poultry Batch": (520, 1070),
        "Create / Edit Batch": (850, 1070),
        "Record Mortality": (1180, 1070),
        "Add Event or Maintenance Report": (850, 1170),
        "Manage Devices": (520, 1325),
        "Control Fan": (850, 1325),
        "Control Water Pump": (1180, 1325),
        "Control Feeder Servo": (850, 1425),
        "Control Light": (1180, 1425),
        "Set Thresholds": (520, 1535),
        "Manage Schedules": (850, 1535),
        "Configure Automation Rules": (1180, 1535),
        "View Reports": (520, 1725),
        "View Analytics": (850, 1725),
        "Compare Batch Reports": (1180, 1725),
        "View Environmental History": (520, 1825),
        "Analyze Mortality Rate": (850, 1825),
        "View Survival Rate": (1180, 1825),
        "View Alerts": (520, 2040),
        "Set Alert Preferences": (850, 2040),
        "Manage App Preferences": (1180, 2040),
        "Access Support Services": (520, 2180),
        "Contact Customer Support": (850, 2180),
        "View Help Center & Policies": (1180, 2180),
    }

    boxes = {name: usecase(draw, x, y, name) for name, (x, y) in positions.items()}

    # Actor associations
    user_targets = [
        "Create Account", "Login", "Manage Profile", "Logout", "View Dashboard",
        "Manage Poultry Batch", "Manage Devices", "Set Thresholds", "View Reports",
        "View Alerts", "Access Support Services",
    ]
    for name in user_targets:
        x, y = positions[name]
        line(draw, (220, 1260), (x - 130, y), USER, width=2, arrow=True)

    hardware_targets = [
        "View Real-Time Sensor Data", "Monitor Temperature", "Monitor Humidity",
        "Monitor Water Level", "Monitor Feed Level", "Control Fan",
        "Control Water Pump", "Control Feeder Servo", "Control Light",
        "Receive Critical Alerts",
    ]
    for name in hardware_targets:
        x, y = positions[name]
        line(draw, (1465, 895), (x + 130, y), DEVICE, width=2, arrow=True)

    support_targets = ["Contact Customer Support", "Access Support Services"]
    for name in support_targets:
        x, y = positions[name]
        line(draw, (1465, 2100), (x + 130, y), SUPPORT, width=2, arrow=True)

    # Include / extend relationships inside the application
    includes = [
        ("Remember Login", "Login", "<<extend>>"),
        ("Manage Profile", "Update Personal Details", "<<include>>"),
        ("Manage Profile", "Change Password", "<<include>>"),
        ("View Dashboard", "View Batch Dashboard", "<<include>>"),
        ("View Dashboard", "View Real-Time Sensor Data", "<<include>>"),
        ("View Real-Time Sensor Data", "Monitor Temperature", "<<include>>"),
        ("View Real-Time Sensor Data", "Monitor Humidity", "<<include>>"),
        ("View Real-Time Sensor Data", "Monitor Water Level", "<<include>>"),
        ("View Real-Time Sensor Data", "Monitor Feed Level", "<<include>>"),
        ("Receive Critical Alerts", "Set Thresholds", "<<extend>>"),
        ("Manage Poultry Batch", "Create / Edit Batch", "<<include>>"),
        ("Manage Poultry Batch", "Record Mortality", "<<include>>"),
        ("Manage Poultry Batch", "Add Event or Maintenance Report", "<<include>>"),
        ("Manage Devices", "Control Fan", "<<include>>"),
        ("Manage Devices", "Control Water Pump", "<<include>>"),
        ("Manage Devices", "Control Feeder Servo", "<<include>>"),
        ("Manage Devices", "Control Light", "<<include>>"),
        ("Configure Automation Rules", "Set Thresholds", "<<include>>"),
        ("Configure Automation Rules", "Manage Schedules", "<<include>>"),
        ("View Reports", "View Analytics", "<<include>>"),
        ("View Reports", "Compare Batch Reports", "<<include>>"),
        ("View Analytics", "View Environmental History", "<<include>>"),
        ("View Analytics", "Analyze Mortality Rate", "<<include>>"),
        ("View Analytics", "View Survival Rate", "<<include>>"),
        ("View Alerts", "Set Alert Preferences", "<<include>>"),
        ("Access Support Services", "Contact Customer Support", "<<include>>"),
        ("Access Support Services", "View Help Center & Policies", "<<include>>"),
    ]
    for src, dst, rel in includes:
        sx, sy = positions[src]
        dx, dy = positions[dst]
        start_x = sx + (130 if dx >= sx else -130)
        end_x = dx - (130 if dx >= sx else -130)
        dashed(draw, (start_x, sy), (end_x, dy), label=rel)

    legend_x, legend_y = 360, 2398
    draw.line((legend_x, legend_y, legend_x + 60, legend_y), fill=USER, width=3)
    draw.text((legend_x + 75, legend_y - 12), "User interaction", font=F_SMALL, fill=TEXT)
    draw.line((legend_x + 285, legend_y, legend_x + 345, legend_y), fill=DEVICE, width=3)
    draw.text((legend_x + 360, legend_y - 12), "Hardware/system interaction", font=F_SMALL, fill=TEXT)
    dashed(draw, (legend_x + 700, legend_y), (legend_x + 760, legend_y), arrow=True, label=None)
    draw.text((legend_x + 775, legend_y - 12), "Include / extend relationship", font=F_SMALL, fill=TEXT)

    image.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()

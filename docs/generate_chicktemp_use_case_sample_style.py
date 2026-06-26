from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "chicktemp_use_case_sample_style.png"

WIDTH = 1900
HEIGHT = 3000

WHITE = "#ffffff"
PAPER = "#fbfbfb"
TEXT = "#222222"
MUTED = "#666666"
BORDER = "#444444"
USER = "#3568d4"
HARDWARE = "#d34646"
SUPPORT = "#2e9d57"
INCLUDE = "#777777"
USECASE_FILL = "#fffdf7"
USECASE_BORDER = "#222222"


def font(kind: str, size: int) -> ImageFont.FreeTypeFont:
    candidates = {
        "regular": [r"C:\Windows\Fonts\arial.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"],
        "bold": [r"C:\Windows\Fonts\arialbd.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"],
    }
    for candidate in candidates[kind]:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


F_TITLE = font("bold", 36)
F_SUB = font("regular", 22)
F_SYSTEM = font("bold", 24)
F_USECASE = font("regular", 18)
F_SMALL = font("regular", 14)
F_ACTOR = font("bold", 18)
F_LEGEND = font("regular", 15)


def text_size(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont) -> tuple[int, int]:
    box = draw.textbbox((0, 0), text, font=fnt)
    return box[2] - box[0], box[3] - box[1]


def wrap_text(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont, width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = word if not current else f"{current} {word}"
        if text_size(draw, candidate, fnt)[0] <= width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def center_text(draw: ImageDraw.ImageDraw, center: tuple[int, int], text: str, fnt: ImageFont.ImageFont, width: int) -> None:
    lines = wrap_text(draw, text, fnt, width)
    line_h = fnt.getbbox("Ag")[3] - fnt.getbbox("Ag")[1] + 4
    y = center[1] - (len(lines) * line_h) / 2
    for line in lines:
        tw, _ = text_size(draw, line, fnt)
        draw.text((center[0] - tw / 2, y), line, font=fnt, fill=TEXT)
        y += line_h


def usecase(draw: ImageDraw.ImageDraw, x: int, y: int, label: str, w: int = 250, h: int = 72) -> tuple[int, int, int, int]:
    box = (x - w // 2, y - h // 2, x + w // 2, y + h // 2)
    draw.ellipse(box, fill=USECASE_FILL, outline=USECASE_BORDER, width=2)
    center_text(draw, (x, y), label, F_USECASE, w - 28)
    return box


def actor(draw: ImageDraw.ImageDraw, x: int, y: int, label: str, color: str) -> None:
    r = 28
    draw.ellipse((x - r, y - 120, x + r, y - 64), outline=color, width=4)
    draw.line((x, y - 64, x, y + 36), fill=color, width=4)
    draw.line((x - 60, y - 25, x + 60, y - 25), fill=color, width=4)
    draw.line((x, y + 36, x - 56, y + 122), fill=color, width=4)
    draw.line((x, y + 36, x + 56, y + 122), fill=color, width=4)
    center_text(draw, (x, y + 172), label, F_ACTOR, 225)


def arrow_head(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], color: str) -> None:
    sx, sy = start
    ex, ey = end
    angle = math.atan2(ey - sy, ex - sx)
    size = 11
    p1 = (ex + size * math.cos(angle + math.pi * 0.82), ey + size * math.sin(angle + math.pi * 0.82))
    p2 = (ex + size * math.cos(angle - math.pi * 0.82), ey + size * math.sin(angle - math.pi * 0.82))
    draw.polygon([end, p1, p2], fill=color)


def straight(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], color: str, width: int = 2, arrow: bool = True) -> None:
    draw.line((start, end), fill=color, width=width)
    if arrow:
        arrow_head(draw, start, end, color)


def polyline(draw: ImageDraw.ImageDraw, pts: list[tuple[int, int]], color: str, width: int = 2, arrow: bool = True) -> None:
    for a, b in zip(pts, pts[1:]):
        draw.line((a, b), fill=color, width=width)
    if arrow and len(pts) >= 2:
        arrow_head(draw, pts[-2], pts[-1], color)


def dashed(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], label: str) -> None:
    sx, sy = start
    ex, ey = end
    dx = ex - sx
    dy = ey - sy
    dist = (dx * dx + dy * dy) ** 0.5
    if not dist:
        return
    ux = dx / dist
    uy = dy / dist
    pos = 0
    while pos < dist:
        nxt = min(pos + 11, dist)
        draw.line((sx + ux * pos, sy + uy * pos, sx + ux * nxt, sy + uy * nxt), fill=INCLUDE, width=2)
        pos += 19
    arrow_head(draw, start, end, INCLUDE)

    mx = (sx + ex) / 2
    my = (sy + ey) / 2
    tw, th = text_size(draw, label, F_SMALL)
    draw.rounded_rectangle((mx - tw / 2 - 5, my - th / 2 - 4, mx + tw / 2 + 5, my + th / 2 + 4), 4, fill=WHITE, outline="#dddddd")
    draw.text((mx - tw / 2, my - th / 2 - 1), label, font=F_SMALL, fill=MUTED)


def main() -> None:
    image = Image.new("RGB", (WIDTH, HEIGHT), WHITE)
    draw = ImageDraw.Draw(image)

    draw.rectangle((24, 24, WIDTH - 24, HEIGHT - 24), outline=BORDER, width=3)
    title = "CHICKTEMP FARM MANAGEMENT MOBILE APP"
    subtitle = "Connected Use Case Diagram"
    tw, _ = text_size(draw, title, F_TITLE)
    sw, _ = text_size(draw, subtitle, F_SUB)
    draw.text(((WIDTH - tw) / 2, 55), title, font=F_TITLE, fill=TEXT)
    draw.text(((WIDTH - sw) / 2, 98), subtitle, font=F_SUB, fill=MUTED)

    boundary = (330, 150, 1580, 2850)
    draw.rounded_rectangle(boundary, radius=10, fill=PAPER, outline=BORDER, width=2)
    system = "ChickTemp Mobile Application"
    sys_w, _ = text_size(draw, system, F_SYSTEM)
    draw.text((boundary[0] + (boundary[2] - boundary[0] - sys_w) / 2, 178), system, font=F_SYSTEM, fill=TEXT)

    actor(draw, 155, 1450, "Farm Manager / User", USER)
    actor(draw, 1740, 1125, "ESP32 / Hardware System", HARDWARE)
    actor(draw, 1740, 2360, "Support Email Service", SUPPORT)

    center_x = 955
    left_x = 595
    right_x = 1315
    cases = {
        # Account
        "Create Account": (left_x, 285),
        "Login": (center_x, 285),
        "Remember Login": (right_x, 285),
        "Manage Account": (center_x, 405),
        "Update Profile": (left_x, 405),
        "Change Password": (right_x, 405),
        "Logout": (center_x, 525),
        # Dashboard and sensor data
        "View Dashboard": (center_x, 690),
        "Select Active Batch": (left_x, 690),
        "View Real-Time Sensor Data": (right_x, 690),
        "Monitor Temperature": (left_x, 810),
        "Monitor Humidity": (center_x, 810),
        "Monitor Water Level": (right_x, 810),
        "Monitor Feed Level": (right_x, 930),
        "Receive Critical Alerts": (center_x, 950),
        # Batch records
        "Manage Poultry Batch": (center_x, 1115),
        "Create / Edit Batch": (left_x, 1115),
        "Record Mortality": (right_x, 1115),
        "Add Event Report": (left_x, 1235),
        "Add Maintenance Report": (right_x, 1235),
        # Device controls
        "Manage Devices": (center_x, 1405),
        "Control Fan": (left_x, 1405),
        "Control Water Pump": (right_x, 1405),
        "Control Feeder Servo": (left_x, 1525),
        "Control Light": (right_x, 1525),
        # Automation
        "Configure Automation Rules": (center_x, 1695),
        "Set Sensor Thresholds": (left_x, 1695),
        "Manage Feeding Schedule": (right_x, 1660),
        "Manage Water Schedule": (right_x, 1745),
        "Manage Lighting Schedule": (left_x, 1810),
        # Reports
        "View Reports": (center_x, 1990),
        "View Analytics": (left_x, 1990),
        "Compare Batch Reports": (right_x, 1990),
        "View Environmental History": (left_x, 2110),
        "Analyze Mortality Rate": (center_x, 2110),
        "View Survival Rate": (right_x, 2110),
        # Preferences and support
        "View Alerts": (center_x, 2290),
        "Set Alert Preferences": (left_x, 2290),
        "Manage App Preferences": (right_x, 2290),
        "Access Support Services": (center_x, 2465),
        "Contact Customer Support": (left_x, 2465),
        "View Help Center & Policies": (right_x, 2465),
    }

    for name, (x, y) in cases.items():
        usecase(draw, x, y, name)

    # User associations are routed through a bus to resemble the sample but stay readable.
    user_bus = 285
    straight(draw, (220, 1450), (user_bus, 1450), USER, width=3, arrow=False)
    straight(draw, (user_bus, 285), (user_bus, 2465), USER, width=3, arrow=False)
    for name in [
        "Create Account", "Login", "Manage Account", "Logout", "View Dashboard",
        "Manage Poultry Batch", "Manage Devices", "Configure Automation Rules",
        "View Reports", "View Alerts", "Access Support Services",
    ]:
        x, y = cases[name]
        straight(draw, (user_bus, y), (x - 125, y), USER, width=2, arrow=True)

    # Hardware actor associations: sensor data and actuator controls.
    hardware_bus = 1635
    straight(draw, (1680, 1125), (hardware_bus, 1125), HARDWARE, width=3, arrow=False)
    straight(draw, (hardware_bus, 690), (hardware_bus, 1525), HARDWARE, width=3, arrow=False)
    for name in [
        "View Real-Time Sensor Data", "Monitor Temperature", "Monitor Humidity",
        "Monitor Water Level", "Monitor Feed Level", "Receive Critical Alerts",
        "Control Fan", "Control Water Pump", "Control Feeder Servo", "Control Light",
    ]:
        x, y = cases[name]
        straight(draw, (hardware_bus, y), (x + 125, y), HARDWARE, width=2, arrow=True)

    # Support service association.
    support_bus = 1635
    straight(draw, (1680, 2360), (support_bus, 2360), SUPPORT, width=3, arrow=False)
    straight(draw, (support_bus, 2465), (support_bus, 2360), SUPPORT, width=3, arrow=False)
    for name in ["Access Support Services", "Contact Customer Support"]:
        x, y = cases[name]
        straight(draw, (support_bus, y), (x + 125, y), SUPPORT, width=2, arrow=True)

    # Main workflow links.
    workflow = [
        "Login", "View Dashboard", "Select Active Batch", "Manage Poultry Batch",
        "Manage Devices", "Configure Automation Rules", "View Reports", "View Alerts",
        "Access Support Services",
    ]
    for a, b in zip(workflow, workflow[1:]):
        ax, ay = cases[a]
        bx, by = cases[b]
        polyline(draw, [(ax, ay + 36), (ax, (ay + by) // 2), (bx, (ay + by) // 2), (bx, by - 36)], "#999999", width=1, arrow=True)

    # Include / extend relationships.
    links = [
        ("Remember Login", "Login", "<<extend>>"),
        ("Manage Account", "Update Profile", "<<include>>"),
        ("Manage Account", "Change Password", "<<include>>"),
        ("View Dashboard", "Select Active Batch", "<<include>>"),
        ("View Dashboard", "View Real-Time Sensor Data", "<<include>>"),
        ("View Real-Time Sensor Data", "Monitor Temperature", "<<include>>"),
        ("View Real-Time Sensor Data", "Monitor Humidity", "<<include>>"),
        ("View Real-Time Sensor Data", "Monitor Water Level", "<<include>>"),
        ("View Real-Time Sensor Data", "Monitor Feed Level", "<<include>>"),
        ("Receive Critical Alerts", "Set Sensor Thresholds", "<<extend>>"),
        ("Manage Poultry Batch", "Create / Edit Batch", "<<include>>"),
        ("Manage Poultry Batch", "Record Mortality", "<<include>>"),
        ("Manage Poultry Batch", "Add Event Report", "<<include>>"),
        ("Manage Poultry Batch", "Add Maintenance Report", "<<include>>"),
        ("Manage Devices", "Control Fan", "<<include>>"),
        ("Manage Devices", "Control Water Pump", "<<include>>"),
        ("Manage Devices", "Control Feeder Servo", "<<include>>"),
        ("Manage Devices", "Control Light", "<<include>>"),
        ("Configure Automation Rules", "Set Sensor Thresholds", "<<include>>"),
        ("Configure Automation Rules", "Manage Feeding Schedule", "<<include>>"),
        ("Configure Automation Rules", "Manage Water Schedule", "<<include>>"),
        ("Configure Automation Rules", "Manage Lighting Schedule", "<<include>>"),
        ("View Reports", "View Analytics", "<<include>>"),
        ("View Reports", "Compare Batch Reports", "<<include>>"),
        ("View Analytics", "View Environmental History", "<<include>>"),
        ("View Analytics", "Analyze Mortality Rate", "<<include>>"),
        ("View Analytics", "View Survival Rate", "<<include>>"),
        ("View Alerts", "Set Alert Preferences", "<<include>>"),
        ("View Alerts", "Manage App Preferences", "<<include>>"),
        ("Access Support Services", "Contact Customer Support", "<<include>>"),
        ("Access Support Services", "View Help Center & Policies", "<<include>>"),
    ]
    for src, dst, label in links:
        sx, sy = cases[src]
        dx, dy = cases[dst]
        start = (sx - 125 if dx < sx else sx + 125, sy)
        end = (dx + 125 if dx < sx else dx - 125, dy)
        dashed(draw, start, end, label)

    # Redraw use cases above connector lines so association lines do not strike through labels.
    for name, (x, y) in cases.items():
        usecase(draw, x, y, name)

    # Legend.
    ly = 2790
    draw.line((500, ly, 560, ly), fill=USER, width=3)
    draw.text((575, ly - 13), "Farm manager interaction", font=F_LEGEND, fill=TEXT)
    draw.line((835, ly, 895, ly), fill=HARDWARE, width=3)
    draw.text((910, ly - 13), "ESP32 / hardware interaction", font=F_LEGEND, fill=TEXT)
    dashed(draw, (1215, ly), (1275, ly), "<<include>>")
    draw.text((1290, ly - 13), "Use case relationship", font=F_LEGEND, fill=TEXT)

    image.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()

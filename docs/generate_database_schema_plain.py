from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "chicktemp_database_schema_with_arrows.png"

WIDTH = 2800
MARGIN_X = 62
TOP_Y = 44

WHITE = "#ffffff"
NEAR_WHITE = "#fbfbfb"
LIGHT = "#f3f3f3"
BORDER = "#b8b8b8"
BORDER_DARK = "#333333"
LINE = "#dddddd"
TEXT = "#2c2c2c"
MUTED = "#666666"


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


F_TITLE = font("bold", 45)
F_SUBTITLE = font("regular", 22)
F_SECTION = font("bold", 25)
F_CARD_TITLE = font("bold", 20)
F_BODY = font("regular", 16)
F_BODY_BOLD = font("bold", 16)
F_SMALL = font("regular", 13)
F_SMALL_BOLD = font("bold", 13)


def text_size(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont) -> tuple[int, int]:
    left, top, right, bottom = draw.textbbox((0, 0), text, font=fnt)
    return right - left, bottom - top


def wrap_text(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont, max_width: int) -> list[str]:
    if not text:
        return [""]

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
            current = ""

        if text_size(draw, word, fnt)[0] <= max_width:
            current = word
            continue

        chunk = ""
        for char in word:
            candidate_chunk = f"{chunk}{char}"
            if text_size(draw, candidate_chunk, fnt)[0] <= max_width:
                chunk = candidate_chunk
            else:
                if chunk:
                    lines.append(chunk)
                chunk = char
        current = chunk

    if current:
        lines.append(current)

    return lines


def line_height(fnt: ImageFont.ImageFont, extra: int = 7) -> int:
    ascent, descent = fnt.getmetrics()
    return ascent + descent + extra


def measure_bullets(draw: ImageDraw.ImageDraw, items: list[str], width: int, fnt: ImageFont.ImageFont) -> int:
    bullet_w = text_size(draw, "- ", fnt)[0]
    lh = line_height(fnt, 4)
    total = 0
    for item in items:
        lines = wrap_text(draw, item, fnt, width - bullet_w)
        total += len(lines) * lh + 2
    return total


def card_height(draw: ImageDraw.ImageDraw, title: str, items: list[str], width: int) -> int:
    pad = 22
    title_lines = wrap_text(draw, title, F_CARD_TITLE, width - pad * 2)
    title_block = len(title_lines) * line_height(F_CARD_TITLE, 4)
    body_block = measure_bullets(draw, items, width - pad * 2, F_BODY)
    return pad + title_block + 14 + 1 + 16 + body_block + pad


def draw_wrapped_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    fnt: ImageFont.ImageFont,
    fill: str,
    max_width: int,
    spacing: int = 4,
) -> int:
    x, y = xy
    for line in wrap_text(draw, text, fnt, max_width):
        draw.text((x, y), line, font=fnt, fill=fill)
        y += line_height(fnt, spacing)
    return y


def draw_bullets(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    items: list[str],
    fnt: ImageFont.ImageFont,
    fill: str,
    max_width: int,
) -> int:
    x, y = xy
    bullet_w = text_size(draw, "- ", fnt)[0]
    lh = line_height(fnt, 4)
    for item in items:
        draw.text((x, y), "- ", font=fnt, fill=fill)
        lines = wrap_text(draw, item, fnt, max_width - bullet_w)
        for i, line in enumerate(lines):
            draw.text((x + bullet_w, y + i * lh), line, font=fnt, fill=fill)
        y += len(lines) * lh + 2
    return y


def draw_card(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    w: int,
    h: int,
    title: str,
    items: list[str],
    fill: str = WHITE,
) -> None:
    radius = 15
    draw.rounded_rectangle((x, y, x + w, y + h), radius=radius, fill=fill, outline=BORDER, width=2)
    pad = 22
    ty = y + pad
    ty = draw_wrapped_text(draw, (x + pad, ty), title, F_CARD_TITLE, TEXT, w - pad * 2, 4)
    divider_y = ty + 8
    draw.line((x + pad, divider_y, x + w - pad, divider_y), fill=LINE, width=1)
    draw_bullets(draw, (x + pad, divider_y + 16), items, F_BODY, TEXT, w - pad * 2)


def draw_section(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    w: int,
    h: int,
    title: str,
    cards: list[tuple[str, list[str]]],
) -> None:
    draw.rounded_rectangle((x, y, x + w, y + h), radius=18, fill=NEAR_WHITE, outline=BORDER, width=2)
    draw.text((x + 20, y + 18), title, font=F_SECTION, fill=TEXT)

    cy = y + 64
    gap = 22
    inner_x = x + 30
    inner_w = w - 60
    for card_title, items in cards:
        ch = card_height(draw, card_title, items, inner_w)
        draw_card(draw, inner_x, cy, inner_w, ch, card_title, items, WHITE)
        cy += ch + gap


def section_height(draw: ImageDraw.ImageDraw, cards: list[tuple[str, list[str]]], width: int) -> int:
    inner_w = width - 60
    gap = 22
    total = 64 + 22
    total += sum(card_height(draw, title, items, inner_w) for title, items in cards)
    total += gap * (len(cards) - 1)
    return total + 26


def draw_centered_text(draw: ImageDraw.ImageDraw, y: int, text: str, fnt: ImageFont.ImageFont, fill: str) -> int:
    w, h = text_size(draw, text, fnt)
    draw.text(((WIDTH - w) / 2, y), text, font=fnt, fill=fill)
    return y + h


def draw_arrow(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int]) -> None:
    sx, sy = start
    ex, ey = end
    draw.line((sx, sy, ex, ey), fill=MUTED, width=3)
    draw.polygon([(ex, ey), (ex - 8, ey - 16), (ex + 8, ey - 16)], fill=MUTED)


def draw_line_arrow(
    draw: ImageDraw.ImageDraw,
    start: tuple[int, int],
    end: tuple[int, int],
    label: str | None = None,
) -> None:
    sx, sy = start
    ex, ey = end
    draw.line((sx, sy, ex, ey), fill=MUTED, width=3)

    angle = math.atan2(ey - sy, ex - sx)
    head_len = 17
    head_width = 8
    back_x = ex - head_len * math.cos(angle)
    back_y = ey - head_len * math.sin(angle)
    perp_x = head_width * math.sin(angle)
    perp_y = -head_width * math.cos(angle)
    draw.polygon(
        [
            (ex, ey),
            (back_x + perp_x, back_y + perp_y),
            (back_x - perp_x, back_y - perp_y),
        ],
        fill=MUTED,
    )

    if label:
        mx = (sx + ex) / 2
        my = (sy + ey) / 2
        tw, th = text_size(draw, label, F_SMALL_BOLD)
        pad_x = 8
        pad_y = 4
        label_box = (
            mx - tw / 2 - pad_x,
            my - th / 2 - pad_y,
            mx + tw / 2 + pad_x,
            my + th / 2 + pad_y,
        )
        draw.rounded_rectangle(label_box, radius=7, fill=WHITE, outline=LINE, width=1)
        draw.text((mx - tw / 2, my - th / 2 - 1), label, font=F_SMALL_BOLD, fill=TEXT)


def draw_top_paths(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, h: int) -> None:
    draw.rounded_rectangle((x, y, x + w, y + h), radius=16, fill=WHITE, outline=BORDER, width=2)
    draw.text((x + 90, y + 34), "Top-Level Paths", font=F_SECTION, fill=TEXT)

    tags = [
        "users",
        "users_by_email",
        "sensor/latest",
        "environmental_logs",
        "controls",
        "support_tickets",
        "user_data/{userId}",
    ]
    cx = x + 390
    cy = y + 28
    for tag in tags:
        tw, th = text_size(draw, tag, F_SMALL_BOLD)
        chip_w = tw + 42
        draw.rounded_rectangle((cx, cy, cx + chip_w, cy + 38), radius=19, fill=LIGHT, outline=BORDER, width=1)
        draw.text((cx + 21, cy + 10), tag, font=F_SMALL_BOLD, fill=TEXT)
        cx += chip_w + 24


def draw_plain_note_card(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, title: str, items: list[str]) -> int:
    h = card_height(draw, title, items, w)
    draw_card(draw, x, y, w, h, title, items, WHITE)
    return h


def draw_relationship_node(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    w: int,
    h: int,
    title: str,
    detail: str | None = None,
) -> tuple[int, int, int, int]:
    draw.rounded_rectangle((x, y, x + w, y + h), radius=12, fill=WHITE, outline=BORDER, width=2)
    title_lines = wrap_text(draw, title, F_SMALL_BOLD, w - 28)
    title_h = len(title_lines) * line_height(F_SMALL_BOLD, 2)
    detail_h = line_height(F_SMALL, 0) if detail else 0
    total_h = title_h + (7 if detail else 0) + detail_h
    ty = y + (h - total_h) / 2
    for line in title_lines:
        tw, _ = text_size(draw, line, F_SMALL_BOLD)
        draw.text((x + (w - tw) / 2, ty), line, font=F_SMALL_BOLD, fill=TEXT)
        ty += line_height(F_SMALL_BOLD, 2)
    if detail:
        dw, _ = text_size(draw, detail, F_SMALL)
        draw.text((x + (w - dw) / 2, ty + 4), detail, font=F_SMALL, fill=MUTED)
    return x, y, x + w, y + h


def right_mid(box: tuple[int, int, int, int]) -> tuple[int, int]:
    return box[2], (box[1] + box[3]) // 2


def left_mid(box: tuple[int, int, int, int]) -> tuple[int, int]:
    return box[0], (box[1] + box[3]) // 2


def top_mid(box: tuple[int, int, int, int]) -> tuple[int, int]:
    return (box[0] + box[2]) // 2, box[1]


def bottom_mid(box: tuple[int, int, int, int]) -> tuple[int, int]:
    return (box[0] + box[2]) // 2, box[3]


def draw_relationship_map(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, h: int) -> None:
    draw.rounded_rectangle((x, y, x + w, y + h), radius=16, fill=NEAR_WHITE, outline=BORDER, width=2)
    draw.text((x + 28, y + 24), "Logical Database Relationships", font=F_SECTION, fill=TEXT)
    draw.text(
        (x + 28, y + 58),
        "Arrows show application-level references in Firebase; they are not enforced SQL foreign keys.",
        font=F_SMALL,
        fill=MUTED,
    )

    node_w = 276
    node_h = 60
    row_gap = 86
    col_gap = 110
    start_x = x + 100
    row1 = y + 98
    row2 = row1 + row_gap
    row3 = row2 + row_gap

    users_by_email = draw_relationship_node(draw, start_x, row1, node_w, node_h, "users_by_email/{emailKey}")
    users = draw_relationship_node(draw, start_x + node_w + col_gap, row1, node_w, node_h, "users/{userId}")
    user_data = draw_relationship_node(draw, start_x + (node_w + col_gap) * 2, row1, node_w, node_h, "user_data/{userId}")
    batches = draw_relationship_node(draw, start_x + (node_w + col_gap) * 3, row1, node_w, node_h, "batches/{batchId}")
    latest = draw_relationship_node(
        draw,
        start_x + (node_w + col_gap) * 4,
        row1,
        node_w,
        node_h,
        "latest_analytics_by_batch",
    )
    snapshots = draw_relationship_node(draw, start_x + (node_w + col_gap) * 5, row1, node_w, node_h, "analytics_snapshots")

    support = draw_relationship_node(draw, start_x, row2, node_w, node_h, "support_tickets/{ticketId}")
    device_configs = draw_relationship_node(draw, start_x + (node_w + col_gap) * 2, row2, node_w, node_h, "device_configs")
    mortality = draw_relationship_node(draw, start_x + (node_w + col_gap) * 3, row2, node_w, node_h, "mortality_records")
    reports = draw_relationship_node(draw, start_x + (node_w + col_gap) * 4, row2, node_w, node_h, "report_records")

    sensor = draw_relationship_node(draw, start_x, row3, node_w, node_h, "sensor/latest")
    logs = draw_relationship_node(draw, start_x + node_w + col_gap, row3, node_w, node_h, "environmental_logs")
    controls = draw_relationship_node(draw, start_x + (node_w + col_gap) * 4, row3, node_w, node_h, "controls/{batchKey}")
    esp32 = draw_relationship_node(draw, start_x + (node_w + col_gap) * 5, row3, node_w, node_h, "ESP32", "reads relay states")

    draw_line_arrow(draw, right_mid(users_by_email), left_mid(users), "references")
    draw_line_arrow(draw, right_mid(users), left_mid(user_data), "owns")
    draw_line_arrow(draw, right_mid(user_data), left_mid(batches), "contains")
    draw_line_arrow(draw, right_mid(batches), left_mid(latest), "summarized")
    draw_line_arrow(draw, right_mid(latest), left_mid(snapshots), "history")

    draw_line_arrow(draw, right_mid(support), (left_mid(users)[0], left_mid(users)[1] + 28), "submitted by")
    draw_line_arrow(draw, bottom_mid(batches), top_mid(device_configs), "configures")
    draw_line_arrow(draw, bottom_mid(batches), top_mid(mortality), "records")
    draw_line_arrow(draw, (bottom_mid(batches)[0] + 18, bottom_mid(batches)[1]), top_mid(reports), "reports")

    draw_line_arrow(draw, right_mid(sensor), left_mid(logs), "feeds")
    draw_line_arrow(draw, right_mid(logs), (left_mid(latest)[0], left_mid(latest)[1] + 28), "used by analytics")
    draw_line_arrow(draw, right_mid(controls), left_mid(esp32), "read by")


def draw_flow(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, h: int) -> None:
    draw.rounded_rectangle((x, y, x + w, y + h), radius=16, fill=NEAR_WHITE, outline=BORDER, width=2)
    draw.text((x + 28, y + 24), "Main Data Flow", font=F_SECTION, fill=TEXT)

    stages = [
        ("Flutter App", "sign up/login, batches, controls, reports, support"),
        ("Firebase RTDB", "stores account, farm, sensor, report, and analytics data"),
        ("ESP32", "writes live sensor data and reads relay controls"),
        ("Analytics", "summarizes logs, mortality, devices, and schedules"),
    ]
    card_w = 455
    card_h = 72
    gap = (w - 2 * 120 - 4 * card_w) // 3
    cy = y + 90
    cx = x + 120
    for i, (stage, detail) in enumerate(stages):
        draw.rounded_rectangle((cx, cy, cx + card_w, cy + card_h), radius=12, fill=WHITE, outline=BORDER, width=2)
        sw, _ = text_size(draw, stage, F_SMALL_BOLD)
        draw.text((cx + (card_w - sw) / 2, cy + 16), stage, font=F_SMALL_BOLD, fill=TEXT)
        dw, _ = text_size(draw, detail, F_SMALL)
        draw.text((cx + (card_w - dw) / 2, cy + 43), detail, font=F_SMALL, fill=MUTED)
        if i < len(stages) - 1:
            ax1 = cx + card_w + 14
            ax2 = cx + card_w + gap - 14
            ay = cy + card_h // 2
            draw.line((ax1, ay, ax2, ay), fill=MUTED, width=3)
            draw.polygon([(ax2, ay), (ax2 - 13, ay - 8), (ax2 - 13, ay + 8)], fill=MUTED)
        cx += card_w + gap


def main() -> None:
    probe = Image.new("RGB", (WIDTH, 100), WHITE)
    draw = ImageDraw.Draw(probe)

    sections = [
        (
            "Authentication & Support",
            [
                (
                    "users/{userId}",
                    [
                        "user_id: string",
                        "full_name: string",
                        "email_address: string",
                        "password_hash: string",
                        "phone_number: string",
                        "role: manager",
                        "profile_photo_base64: string",
                        "starts_with_empty_controls: bool",
                    ],
                ),
                (
                    "users_by_email/{emailKey}",
                    [
                        "user_id: string; points to users/{userId}",
                        "emailKey is a base64Url-encoded email address.",
                    ],
                ),
                (
                    "support_tickets/{ticketId}",
                    [
                        "ticket_id: string",
                        "subject: string",
                        "message: string",
                        "created_at: ISO datetime",
                        "status: open",
                        "user_id: string",
                        "full_name: string",
                        "email_address: string",
                        "phone_number: string",
                    ],
                ),
                (
                    "Auth Relationships",
                    [
                        "users_by_email maps an email to a user account.",
                        "support_tickets stores Contact Support messages and sends an email copy through FormSubmit.",
                        "user_id links support tickets back to users/{userId}.",
                    ],
                ),
            ],
        ),
        (
            "Live Sensor & Device Control",
            [
                (
                    "sensor/latest",
                    [
                        "status: ok | no_read",
                        "temperature: number",
                        "humidity: number",
                        "water_status: ok | no_read",
                        "water_level_percent: number",
                        "water_distance_cm: number",
                        "feeder_status: ok | no_read",
                        "feeder_level_percent: number",
                        "feeder_distance_cm: number",
                        "water_pump_enabled: bool",
                        "light_bulb_enabled: bool",
                        "ventilation_fan_enabled: bool",
                        "feeder_servo_enabled: bool",
                        "device: esp32-dht22-hcsr04",
                        "updated_at: server timestamp",
                    ],
                ),
                (
                    "environmental_logs/{logId}",
                    [
                        "user_id: string",
                        "batch_id: string",
                        "device_id: string",
                        "temperature: number",
                        "humidity: number",
                        "sample_count: number",
                        "aggregation_minutes: 15",
                        "water_level_percent: number",
                        "water_distance_cm: number",
                        "feeder_level_percent: number",
                        "feeder_distance_cm: number",
                        "recorded_at: timestamp",
                    ],
                ),
                (
                    "controls/{batchKey}",
                    [
                        "water_pump/{ enabled, source, updated_at }",
                        "light_bulb/{ enabled, source, updated_at }",
                        "ventilation_fan/{ enabled, source, updated_at }",
                        "feeder_servo/{ enabled, source, updated_at }",
                        "App writes relay states; ESP32 reads them to control hardware.",
                    ],
                ),
            ],
        ),
        (
            "Per-User Farm Records",
            [
                (
                    "user_data/{userId}/batches/{batchId}",
                    [
                        "batch_id: string",
                        "batch_name: string",
                        "started_at_label: string",
                        "day_label: Day x / total",
                        "total_chickens: number",
                        "mortality_count: number",
                        "is_active: bool",
                    ],
                ),
                (
                    "user_data/{userId}/device_configs",
                    [
                        "ventilation_configs/{batchKey}",
                        "feeder_configs/{batchKey}",
                        "water_configs/{batchKey}",
                        "lighting_configs/{batchKey}",
                        "main_enabled: bool",
                        "expanded: bool",
                        "devices[]: name, id, type, description, enabled",
                        "global_schedules[]: Active / Inactive",
                        "device_schedules[]: deviceId -> schedules[]",
                        "extra fields include fan speed and lighting brightness.",
                    ],
                ),
                (
                    "user_data/{userId}/mortality_records/{batchId}/{recordId}",
                    [
                        "record_id: string",
                        "batch_id: string",
                        "deaths: number",
                        "date: ISO datetime",
                        "note: string",
                        "recorded_at: server timestamp",
                    ],
                ),
                (
                    "user_data/{userId}/report_records/{batchId}",
                    [
                        "events/{entryId}",
                        "maintenance/{entryId}",
                        "title: string",
                        "date: dd/mm/yyyy",
                        "description: string",
                        "updated_at: ISO datetime",
                    ],
                ),
            ],
        ),
        (
            "Analytics, Snapshots & Local Cache",
            [
                (
                    "user_data/{userId}/latest_analytics_by_batch/{batchKey}",
                    [
                        "batch_name: string",
                        "average_temperature: number",
                        "average_humidity: number",
                        "total_chickens: number",
                        "mortality_count: number",
                        "alive_chickens: number",
                        "survival_rate: number",
                        "water_tank_level: number/null",
                        "feeder_level: number/null",
                        "device_count: number",
                        "active_schedule_count: number",
                        "environmental_log_count: number",
                        "recorded_at: server timestamp",
                    ],
                ),
                (
                    "user_data/{userId}/analytics_snapshots/{snapshotId}",
                    [
                        "Same payload as latest_analytics_by_batch.",
                        "Created with POST for historical analytics snapshots.",
                        "Used for dashboard and analytics review.",
                    ],
                ),
                (
                    "Local SharedPreferences (not Firebase)",
                    [
                        "remember_me and remembered_email",
                        "cached batches and cached telemetry",
                        "temperature threshold settings",
                        "alert preferences and read alert IDs",
                        "cached environmental logs for offline sync",
                    ],
                ),
                (
                    "Derived Data Notes",
                    [
                        "Analytics is calculated from environmental logs, live sensor snapshots, device configs, batches, and mortality records.",
                        "Temperature alert thresholds and alert preferences are local unless Firebase sync is added later.",
                    ],
                ),
            ],
        ),
    ]

    col_gap = 35
    col_w = int((WIDTH - MARGIN_X * 2 - col_gap * 3) / 4)
    main_y = 388
    main_heights = [section_height(draw, cards, col_w) for _, cards in sections]
    main_h = max(main_heights)

    relationship_y = main_y + main_h + 24
    relationship_h = 392

    note_y = relationship_y + relationship_h + 24
    note_items = [
        "Arrows show logical references used by the app; Firebase does not enforce relational foreign keys.",
        "users/{userId} owns user_data/{userId}.",
        "batchId/batchKey links batches to configs, mortality, reports, logs, and analytics.",
        "sensor/latest and environmental_logs feed analytics.",
    ]
    note_h = card_height(draw, "Relationship Notes", note_items, WIDTH - MARGIN_X * 2)

    flow_y = note_y + note_h + 24
    flow_h = 190

    nosql_y = flow_y + flow_h + 24
    nosql_items = [
        "Firebase stores this as a JSON tree. Keys such as userId, batchId, batchKey, logId, and ticketId act as references between branches."
    ]
    nosql_h = card_height(draw, "NoSQL Note", nosql_items, WIDTH - MARGIN_X * 2)

    height = nosql_y + nosql_h + 58
    image = Image.new("RGB", (WIDTH, height), WHITE)
    draw = ImageDraw.Draw(image)

    draw.rectangle((24, 24, WIDTH - 24, height - 24), outline=BORDER_DARK, width=3)
    title_bottom = draw_centered_text(draw, TOP_Y, "CHICKTEMP DATABASE SCHEMA", F_TITLE, TEXT)
    draw_centered_text(
        draw,
        title_bottom + 7,
        "Firebase Realtime Database structure based on the implemented mobile app and ESP32 sketch",
        F_SUBTITLE,
        MUTED,
    )

    root_w = 1360
    root_h = 82
    root_x = (WIDTH - root_w) // 2
    root_y = 132
    draw.rounded_rectangle(
        (root_x, root_y, root_x + root_w, root_y + root_h),
        radius=16,
        fill=LIGHT,
        outline=BORDER,
        width=2,
    )
    root_text = "Firebase Realtime Database Root"
    rw, rh = text_size(draw, root_text, F_CARD_TITLE)
    draw.text((root_x + (root_w - rw) / 2, root_y + (root_h - rh) / 2 - 2), root_text, font=F_CARD_TITLE, fill=TEXT)
    draw_arrow(draw, (WIDTH // 2, root_y + root_h), (WIDTH // 2, 251))

    top_paths_y = 260
    draw_top_paths(draw, MARGIN_X + 22, top_paths_y, WIDTH - (MARGIN_X + 22) * 2, 92)

    x = MARGIN_X
    for title, cards in sections:
        draw_section(draw, x, main_y, col_w, main_h, title, cards)
        x += col_w + col_gap

    draw_relationship_map(draw, MARGIN_X, relationship_y, WIDTH - MARGIN_X * 2, relationship_h)
    draw_plain_note_card(draw, MARGIN_X, note_y, WIDTH - MARGIN_X * 2, "Relationship Notes", note_items)
    draw_flow(draw, MARGIN_X, flow_y, WIDTH - MARGIN_X * 2, flow_h)
    draw_plain_note_card(draw, MARGIN_X, nosql_y, WIDTH - MARGIN_X * 2, "NoSQL Note", nosql_items)

    image.save(OUT)
    print(OUT)
    print(f"{WIDTH}x{height}")


if __name__ == "__main__":
    main()

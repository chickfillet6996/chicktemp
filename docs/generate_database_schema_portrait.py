from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

from generate_database_schema_plain import (
    BORDER,
    BORDER_DARK,
    F_CARD_TITLE,
    F_SECTION,
    F_SMALL_BOLD,
    F_SUBTITLE,
    F_TITLE,
    LIGHT,
    LINE,
    MARGIN_X,
    MUTED,
    NEAR_WHITE,
    TEXT,
    WHITE,
    draw_section,
    line_height,
    section_height,
    text_size,
    wrap_text,
)


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "chicktemp_database_schema_portrait.png"

WIDTH = 1650
TOP_Y = 42
SIDE_MARGIN = 48


def schema_sections() -> list[tuple[str, list[tuple[str, list[str]]]]]:
    return [
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


def draw_centered(draw: ImageDraw.ImageDraw, y: int, text: str, fnt, fill: str) -> int:
    tw, th = text_size(draw, text, fnt)
    draw.text(((WIDTH - tw) / 2, y), text, font=fnt, fill=fill)
    return y + th


def draw_wrapped_centered(draw: ImageDraw.ImageDraw, y: int, text: str, fnt, fill: str, max_width: int) -> int:
    for line in wrap_text(draw, text, fnt, max_width):
        tw, _ = text_size(draw, line, fnt)
        draw.text(((WIDTH - tw) / 2, y), line, font=fnt, fill=fill)
        y += line_height(fnt, 2)
    return y


def draw_top_paths_portrait(draw: ImageDraw.ImageDraw, x: int, y: int, w: int) -> int:
    tags = [
        "users",
        "users_by_email",
        "sensor/latest",
        "environmental_logs",
        "controls",
        "support_tickets",
        "user_data/{userId}",
    ]

    chip_h = 38
    title_w = 245
    row_gap = 12
    chip_gap = 14
    chip_y = y + 28
    chip_x = x + title_w
    max_x = x + w - 22
    row_count = 1

    for tag in tags:
        tw, _ = text_size(draw, tag, F_SMALL_BOLD)
        chip_w = tw + 42
        if chip_x + chip_w > max_x:
            chip_x = x + title_w
            chip_y += chip_h + row_gap
            row_count += 1
        chip_x += chip_w + chip_gap

    h = 56 + row_count * chip_h + (row_count - 1) * row_gap
    draw.rounded_rectangle((x, y, x + w, y + h), radius=16, fill=WHITE, outline=BORDER, width=2)
    draw.text((x + 36, y + 36), "Top-Level Paths", font=F_SECTION, fill=TEXT)

    chip_y = y + 28
    chip_x = x + title_w
    for tag in tags:
        tw, _ = text_size(draw, tag, F_SMALL_BOLD)
        chip_w = tw + 42
        if chip_x + chip_w > max_x:
            chip_x = x + title_w
            chip_y += chip_h + row_gap
        draw.rounded_rectangle((chip_x, chip_y, chip_x + chip_w, chip_y + chip_h), radius=19, fill=LIGHT, outline=BORDER, width=1)
        draw.text((chip_x + 21, chip_y + 10), tag, font=F_SMALL_BOLD, fill=TEXT)
        chip_x += chip_w + chip_gap

    return h


def draw_root(draw: ImageDraw.ImageDraw, y: int) -> int:
    root_w = WIDTH - SIDE_MARGIN * 4
    root_h = 72
    root_x = (WIDTH - root_w) // 2
    draw.rounded_rectangle((root_x, y, root_x + root_w, y + root_h), radius=16, fill=LIGHT, outline=BORDER, width=2)
    text = "Firebase Realtime Database Root"
    tw, th = text_size(draw, text, F_CARD_TITLE)
    draw.text((root_x + (root_w - tw) / 2, y + (root_h - th) / 2 - 2), text, font=F_CARD_TITLE, fill=TEXT)
    return y + root_h


def main() -> None:
    probe = Image.new("RGB", (WIDTH, 100), WHITE)
    draw = ImageDraw.Draw(probe)
    sections = schema_sections()

    gap = 26
    col_w = (WIDTH - SIDE_MARGIN * 2 - gap) // 2
    section_heights = [section_height(draw, cards, col_w) for _, cards in sections]
    row1_h = max(section_heights[0], section_heights[1])
    row2_h = max(section_heights[2], section_heights[3])

    header_h = 260
    top_paths_h = 112
    body_y = header_h + top_paths_h + 40
    height = body_y + row1_h + gap + row2_h + 62

    image = Image.new("RGB", (WIDTH, height), WHITE)
    draw = ImageDraw.Draw(image)
    draw.rectangle((20, 20, WIDTH - 20, height - 20), outline=BORDER_DARK, width=3)

    title_bottom = draw_centered(draw, TOP_Y, "CHICKTEMP DATABASE SCHEMA", F_TITLE, TEXT)
    draw_wrapped_centered(
        draw,
        title_bottom + 8,
        "Firebase Realtime Database structure based on the implemented mobile app and ESP32 sketch",
        F_SUBTITLE,
        MUTED,
        WIDTH - SIDE_MARGIN * 2,
    )

    root_bottom = draw_root(draw, 128)
    arrow_x = WIDTH // 2
    draw.line((arrow_x, root_bottom, arrow_x, root_bottom + 35), fill=MUTED, width=3)
    draw.polygon(
        [(arrow_x, root_bottom + 48), (arrow_x - 8, root_bottom + 32), (arrow_x + 8, root_bottom + 32)],
        fill=MUTED,
    )

    top_paths_y = root_bottom + 54
    top_paths_h = draw_top_paths_portrait(draw, SIDE_MARGIN, top_paths_y, WIDTH - SIDE_MARGIN * 2)
    body_y = top_paths_y + top_paths_h + 32

    left_x = SIDE_MARGIN
    right_x = SIDE_MARGIN + col_w + gap
    draw_section(draw, left_x, body_y, col_w, row1_h, sections[0][0], sections[0][1])
    draw_section(draw, right_x, body_y, col_w, row1_h, sections[1][0], sections[1][1])

    row2_y = body_y + row1_h + gap
    draw_section(draw, left_x, row2_y, col_w, row2_h, sections[2][0], sections[2][1])
    draw_section(draw, right_x, row2_y, col_w, row2_h, sections[3][0], sections[3][1])

    image.save(OUT)
    print(OUT)
    print(f"{WIDTH}x{height}")


if __name__ == "__main__":
    main()

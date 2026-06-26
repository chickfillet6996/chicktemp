from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

import generate_database_schema_plain as base
from generate_database_schema_portrait import schema_sections


ROOT = Path(__file__).resolve().parent
OUT_DIR = ROOT / "word_readable_schema"

WIDTH = 1800
SIDE_MARGIN = 70
TOP_MARGIN = 55


def configure_word_fonts() -> None:
    base.F_TITLE = base.font("bold", 56)
    base.F_SUBTITLE = base.font("regular", 26)
    base.F_SECTION = base.font("bold", 38)
    base.F_CARD_TITLE = base.font("bold", 31)
    base.F_BODY = base.font("regular", 26)
    base.F_BODY_BOLD = base.font("bold", 26)
    base.F_SMALL = base.font("regular", 22)
    base.F_SMALL_BOLD = base.font("bold", 22)


def draw_centered(draw: ImageDraw.ImageDraw, y: int, text: str, fnt, fill: str) -> int:
    tw, th = base.text_size(draw, text, fnt)
    draw.text(((WIDTH - tw) / 2, y), text, font=fnt, fill=fill)
    return y + th


def safe_filename(title: str) -> str:
    return (
        title.lower()
        .replace("&", "and")
        .replace(",", "")
        .replace(" ", "_")
        .replace("-", "_")
    )


def draw_section_page(index: int, title: str, cards: list[tuple[str, list[str]]]) -> Path:
    section_w = WIDTH - SIDE_MARGIN * 2
    probe = Image.new("RGB", (WIDTH, 100), base.WHITE)
    probe_draw = ImageDraw.Draw(probe)
    section_h = base.section_height(probe_draw, cards, section_w)

    header_h = 150
    height = TOP_MARGIN + header_h + section_h + 70
    image = Image.new("RGB", (WIDTH, height), base.WHITE)
    draw = ImageDraw.Draw(image)

    draw.rectangle((24, 24, WIDTH - 24, height - 24), outline=base.BORDER_DARK, width=3)
    title_bottom = draw_centered(draw, TOP_MARGIN, "CHICKTEMP DATABASE SCHEMA", base.F_TITLE, base.TEXT)
    draw_centered(draw, title_bottom + 8, f"Part {index}: {title}", base.F_SUBTITLE, base.MUTED)

    y = TOP_MARGIN + header_h
    base.draw_section(draw, SIDE_MARGIN, y, section_w, section_h, title, cards)

    output = OUT_DIR / f"chicktemp_database_schema_word_{index:02d}_{safe_filename(title)}.png"
    image.save(output)
    return output


def main() -> None:
    configure_word_fonts()
    OUT_DIR.mkdir(exist_ok=True)

    outputs = []
    for index, (title, cards) in enumerate(schema_sections(), start=1):
        outputs.append(draw_section_page(index, title, cards))

    for output in outputs:
        with Image.open(output) as image:
            print(f"{output} {image.width}x{image.height}")


if __name__ == "__main__":
    main()

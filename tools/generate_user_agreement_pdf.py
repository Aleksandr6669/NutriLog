from pathlib import Path

from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer

ROOT = Path(__file__).resolve().parents[1]
SOURCE_MD = ROOT / 'USER_AGREEMENT.md'
OUT_DIR = ROOT / 'docs'
OUT_PDF = OUT_DIR / 'USER_AGREEMENT.pdf'


def find_font_path() -> str:
    candidates = [
        '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/System/Library/Fonts/Supplemental/Times New Roman.ttf',
        '/Library/Fonts/Arial.ttf',
    ]
    for path in candidates:
        if Path(path).exists():
            return path
    raise RuntimeError('No suitable Cyrillic TTF font found on system.')


def esc(text: str) -> str:
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def build_pdf() -> None:
    if not SOURCE_MD.exists():
        raise FileNotFoundError(f'Missing source file: {SOURCE_MD}')

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    font_path = find_font_path()
    pdfmetrics.registerFont(TTFont('AppFont', font_path))

    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name='TitleRu',
            parent=styles['Title'],
            fontName='AppFont',
            alignment=TA_CENTER,
            fontSize=18,
            leading=22,
            spaceAfter=14,
        )
    )
    styles.add(
        ParagraphStyle(
            name='HeadingRu',
            parent=styles['Heading2'],
            fontName='AppFont',
            fontSize=13,
            leading=16,
            spaceBefore=10,
            spaceAfter=6,
        )
    )
    styles.add(
        ParagraphStyle(
            name='BodyRu',
            parent=styles['BodyText'],
            fontName='AppFont',
            fontSize=10.5,
            leading=15,
            alignment=TA_JUSTIFY,
        )
    )

    doc = SimpleDocTemplate(
        str(OUT_PDF),
        pagesize=A4,
        rightMargin=42,
        leftMargin=42,
        topMargin=42,
        bottomMargin=42,
        title='Пользовательское соглашение NutriLog',
    )

    story = []
    for raw in SOURCE_MD.read_text(encoding='utf-8').splitlines():
        line = raw.strip()
        if not line:
            story.append(Spacer(1, 6))
            continue

        if line.startswith('# '):
            story.append(Paragraph(esc(line[2:].strip()), styles['TitleRu']))
            continue

        if line.startswith('## '):
            story.append(Paragraph(esc(line[3:].strip()), styles['HeadingRu']))
            continue

        if line.startswith('---'):
            story.append(Spacer(1, 10))
            continue

        if line.startswith('- '):
            story.append(Paragraph(esc('• ' + line[2:].strip()), styles['BodyRu']))
            story.append(Spacer(1, 2))
            continue

        story.append(Paragraph(esc(line), styles['BodyRu']))
        if line[:2].isdigit() and line[1:3] == '. ':
            story.append(Spacer(1, 2))

    doc.build(story)


if __name__ == '__main__':
    build_pdf()
    print(f'PDF created: {OUT_PDF}')

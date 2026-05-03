import json
from pathlib import Path

from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer

ROOT = Path(__file__).resolve().parents[1]
L10N_DIR = ROOT / 'lib' / 'l10n'
OUT_DIR = ROOT / 'docs' / 'agreements'

LOCALES = ['ru', 'en', 'uk']

TITLE_BY_LOCALE = {
    'ru': 'Пользовательское соглашение NutriLog',
    'en': 'NutriLog User Agreement',
    'uk': 'Користувацька угода NutriLog',
}

EFFECTIVE_DATE_BY_LOCALE = {
    'ru': 'Дата вступления в силу: 03.05.2026',
    'en': 'Effective date: 2026-05-03',
    'uk': 'Дата набрання чинності: 03.05.2026',
}

FOOTER_BY_LOCALE = {
    'ru': 'Продолжая использовать приложение NutriLog, вы подтверждаете, что ознакомились с условиями пользовательского соглашения и принимаете их.',
    'en': 'By continuing to use the NutriLog app, you confirm that you have read and accepted the terms of this user agreement.',
    'uk': 'Продовжуючи використовувати застосунок NutriLog, ви підтверджуєте, що ознайомилися з умовами користувацької угоди та приймаєте їх.',
}


def find_font_path() -> str:
    candidates = [
        '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/System/Library/Fonts/Supplemental/Times New Roman.ttf',
        '/Library/Fonts/Arial.ttf',
    ]
    for path in candidates:
        if Path(path).exists():
            return path
    raise RuntimeError('No suitable TTF font found on system.')


def esc(text: str) -> str:
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def load_arb(locale: str) -> dict:
    arb_path = L10N_DIR / f'app_{locale}.arb'
    with arb_path.open('r', encoding='utf-8') as f:
        return json.load(f)


def compose_markdown(locale: str, data: dict) -> str:
    lines = [
        f"# {TITLE_BY_LOCALE[locale]}",
        '',
        EFFECTIVE_DATE_BY_LOCALE[locale],
        '',
        f"## {data['agreementSection1Title']}",
        '',
        data['agreementSection1Content'],
        '',
        f"## {data['agreementSection2Title']}",
        '',
        data['agreementSection2Content'],
        '',
        f"## {data['agreementSection3Title']}",
        '',
        data['agreementSection3Content'],
        '',
        f"## {data['agreementSection4Title']}",
        '',
        data['agreementSection4Content'],
        '',
        f"- {data['agreementCheckboxText']}",
        f"- {data['agreementContinueText']}",
        '',
        '---',
        '',
        FOOTER_BY_LOCALE[locale],
        '',
    ]
    return '\n'.join(lines)


def render_pdf_from_markdown(markdown_text: str, title: str, out_pdf: Path) -> None:
    font_path = find_font_path()
    if 'AppFont' not in pdfmetrics.getRegisteredFontNames():
        pdfmetrics.registerFont(TTFont('AppFont', font_path))

    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name='TitleStyle',
            parent=styles['Title'],
            fontName='AppFont',
            alignment=TA_CENTER,
            fontSize=18,
            leading=22,
            spaceAfter=12,
        )
    )
    styles.add(
        ParagraphStyle(
            name='HeadingStyle',
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
            name='BodyStyle',
            parent=styles['BodyText'],
            fontName='AppFont',
            fontSize=10.5,
            leading=15,
            alignment=TA_JUSTIFY,
        )
    )

    doc = SimpleDocTemplate(
        str(out_pdf),
        pagesize=A4,
        rightMargin=42,
        leftMargin=42,
        topMargin=42,
        bottomMargin=42,
        title=title,
    )

    story = []
    for raw in markdown_text.splitlines():
        line = raw.strip()
        if not line:
            story.append(Spacer(1, 6))
            continue

        if line.startswith('# '):
            story.append(Paragraph(esc(line[2:].strip()), styles['TitleStyle']))
            continue

        if line.startswith('## '):
            story.append(Paragraph(esc(line[3:].strip()), styles['HeadingStyle']))
            continue

        if line.startswith('---'):
            story.append(Spacer(1, 10))
            continue

        if line.startswith('- '):
            story.append(Paragraph(esc('• ' + line[2:].strip()), styles['BodyStyle']))
            story.append(Spacer(1, 2))
            continue

        story.append(Paragraph(esc(line), styles['BodyStyle']))

    doc.build(story)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for locale in LOCALES:
        data = load_arb(locale)
        md_text = compose_markdown(locale, data)

        md_path = OUT_DIR / f'USER_AGREEMENT_{locale}.md'
        pdf_path = OUT_DIR / f'USER_AGREEMENT_{locale}.pdf'

        md_path.write_text(md_text, encoding='utf-8')
        render_pdf_from_markdown(md_text, TITLE_BY_LOCALE[locale], pdf_path)

        print(f'Generated: {md_path}')
        print(f'Generated: {pdf_path}')


if __name__ == '__main__':
    main()

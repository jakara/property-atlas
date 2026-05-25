#!/usr/bin/env python3
"""OCR 55-page Chinese scanned PDF → reports/extracted/raw/pdf_ocr.txt + page_NN.txt."""
import sys, os
from pathlib import Path
import subprocess
import json

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / 'reports' / '天津学校情况(4).pdf'
OUT_DIR = ROOT / 'reports' / 'extracted' / 'raw' / 'pdf_pages'
OUT_DIR.mkdir(parents=True, exist_ok=True)
COMBINED = ROOT / 'reports' / 'extracted' / 'raw' / 'pdf_ocr.txt'

from pdf2image import convert_from_path
import pytesseract

images = convert_from_path(str(PDF), dpi=250)
print(f'Pages: {len(images)}')
combined = []
for i, img in enumerate(images, 1):
    pg_txt = pytesseract.image_to_string(img, lang='chi_sim+eng', config='--psm 6')
    fn = OUT_DIR / f'page_{i:02d}.txt'
    fn.write_text(pg_txt, encoding='utf-8')
    combined.append(f'\n<!-- page {i} -->\n{pg_txt}')
    if i % 5 == 0:
        print(f'  done page {i}/{len(images)} ({len(pg_txt)} chars)')
COMBINED.write_text('\n'.join(combined), encoding='utf-8')
print(f'Wrote combined to {COMBINED}')

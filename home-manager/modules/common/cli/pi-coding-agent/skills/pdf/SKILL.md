---
name: pdf
description: Use when tasks involve reading, creating, editing, or reviewing PDF files, especially when layout, tables, forms, or visual rendering matter.
---

# PDF Skill

## When to use

Use this skill when the task involves a PDF file, including:

- Reading or reviewing PDF content where layout or visuals matter.
- Extracting text, tables, metadata, images, or page ranges.
- Creating or editing PDFs programmatically.
- Merging, splitting, rotating, watermarking, encrypting, or repairing PDFs.
- Inspecting, filling, or annotating forms.
- Validating the final PDF rendering before delivery.

For a non-sensitive URL PDF, Pi's `fetch_content` can extract readable content. It may use hosted extraction providers depending on Pi Web Access configuration. For sensitive documents, prefer obtaining the file locally and using local tools.

## Workflow

1. Establish the input and output paths. Do not overwrite the user's original unless they explicitly request it.
2. Inspect the input before editing:
   - Run `pdfinfo <input.pdf>` for page count, dimensions, metadata, encryption, and file size.
   - Use `pdftotext -layout <input.pdf> -` for a quick text and layout check.
   - Render representative pages with `pdftoppm -png <input.pdf> <prefix>` when visual fidelity matters.
3. Apply basic safety limits to untrusted files. Check file size and page count before processing. Use bounded output directories and clean up failed intermediate work. Do not open untrusted PDFs in a GUI or execute embedded attachments/JavaScript.
4. Choose the least complex local tool that preserves the required information:
   - `pypdf` for basic reading, page operations, metadata, and encryption.
   - `pdfplumber` for layout-aware text and table extraction.
   - `reportlab` for creating new PDFs.
   - Poppler tools such as `pdftotext`, `pdftoppm`, and `pdfimages` for inspection and extraction.
   - `qpdf` for structural checks, repair, optimization, and advanced page operations when installed.
5. For scanned PDFs, render pages and use OCR only when text extraction is insufficient. Check OCR output against the page images.
6. After every meaningful edit, render the changed pages and inspect the images with Pi's image-capable file reader. Check alignment, spacing, clipping, table structure, glyphs, page ordering, blank pages, and legibility.
7. Do not report success until the output file exists, opens successfully, and the final checks pass.

## Dependencies

Check for tools before using them. Poppler (`pdfinfo`, `pdftotext`, `pdftoppm`, `pdfimages`) and `qpdf` are provided by the system package set on this machine; verify with `command -v pdftotext qpdf` and fall back to the platform manager otherwise:

```bash
# macOS
brew install poppler qpdf
# Debian/Ubuntu
sudo apt install poppler-utils qpdf
```

For Python libraries, prefer ephemeral `uv` runs that need no environment to create or activate:

```bash
uv run --with pypdf --with pdfplumber --with reportlab python -- -c "import pypdf"
```

Or, when a persistent project environment already exists, install into it:

```bash
uv pip install pypdf pdfplumber reportlab
```

Install OCR dependencies only when needed:

```bash
uv run --with pytesseract --with pdf2image python -- -c "import pytesseract"
brew install tesseract poppler
```

Do not install dependencies globally without checking the repository's package or environment conventions first. This skill provides procedure, not a bundled PDF runtime.

## Rendering

Render a PDF to PNGs with:

```bash
mkdir -p tmp/pdfs
pdftoppm -png "$INPUT_PDF" "tmp/pdfs/page"
```

For higher-resolution inspection:

```bash
pdftoppm -png -r 200 "$INPUT_PDF" "tmp/pdfs/page"
```

Inspect the generated images, not just extracted text. Look for clipped text, overlapping elements, broken tables, blank pages, black squares, incorrect page ordering, and unreadable glyphs.

## Extraction examples

Run the snippets below with ephemeral dependencies rather than a global python; for example:

```bash
uv run --with pypdf --with pdfplumber --with reportlab python - <<'PY'
from pypdf import PdfReader
...
PY
```

```python
from pypdf import PdfReader

reader = PdfReader("document.pdf")
print(f"Pages: {len(reader.pages)}")
for page in reader.pages:
    print(page.extract_text() or "")
```

```python
import pdfplumber

with pdfplumber.open("document.pdf") as pdf:
    for page_number, page in enumerate(pdf.pages, start=1):
        print(f"--- Page {page_number} ---")
        print(page.extract_text() or "")
        for table in page.extract_tables():
            for row in table:
                print(row)
```

Use `pdftotext -bbox-layout` or `pdfplumber` coordinates when exact placement or table reconstruction matters. Do not assume extracted text preserves visual layout.

## Creating and editing

Use `reportlab` for new documents and explicitly control page size, margins, typography, spacing, and table widths. Use `pypdf` for page-level operations. Use `qpdf --check` when available to validate PDF structure.

Avoid Unicode subscript and superscript glyphs with ReportLab's built-in fonts. Use ReportLab markup such as `<sub>` and `<super>`, or embed a font that contains the required glyphs.

## Forms and annotations

First determine whether the PDF has AcroForm fields. Inspect fields before writing values. If it has no fillable fields, treat it as a visual annotation problem: determine coordinates from the PDF structure first, then render and visually verify placement. Never assume a blank line is an AcroForm field.

Do not attempt to bypass password protection. Ask the user for the password when authorized access is required, and avoid writing decrypted copies unless requested.

## Sensitive documents and hosted tools

Before sending a PDF to `fetch_content` or any hosted OCR/extraction provider, confirm that the document is suitable for external processing. For confidential, personal, regulated, or proprietary PDFs, use local Poppler/Python tools whenever possible. State when a hosted provider is being used and which content it may receive.

## Final checks

- Confirm the output file exists and opens successfully.
- Confirm page count and ordering.
- Run `qpdf --check` when `qpdf` is available.
- Re-render the final output and inspect the latest PNGs.
- Confirm headers, footers, page numbers, margins, tables, and section transitions.
- Confirm citations and references are human-readable.
- Remove intermediate files unless the user asks to keep them.

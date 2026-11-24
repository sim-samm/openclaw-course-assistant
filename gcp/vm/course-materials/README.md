# Course materials (operator staging)

Place slide **PDFs** here before running [`../setup-course-materials.sh`](../setup-course-materials.sh).

## From Desktop zip (`cs112_lecture_slids.zip`)

1. Unzip PPTX into `pptx-source/` (already done if you followed the lecture export).
2. Convert to PDF with LibreOffice (`soffice --headless --convert-to pdf …`) into `pdf-raw/`.
3. Run `./prep-pdfs-for-openclaw.sh` — produces **one PDF per lecture** (`cs112-01-models-prompts.pdf`, …).

## OpenClaw limits

The gateway patch [`course-tools.patch.json5`](../course-tools.patch.json5) sets `pdfMaxBytesMb: 10` and `pdfMaxPages: 70`. Most decks here are **4–7 MB** and **15–66 pages**. Prefer naming a **single lecture file** in Slack prompts (e.g. `course/cs112-04-agents.pdf`).

Only **lecture 06 (Multimedia)** is large (~60+ MB raw); Ghostscript compression usually brings it under ~10 MB.

## Git

**Do not commit** PDFs, `pdf-raw/`, or `pptx-source/` (~300 MB). They are listed in [`gcp/.gitignore`](../../.gitignore). Commit only `README.md` and `prep-pdfs-for-openclaw.sh`; operators regenerate PDFs locally, then run `../setup-course-materials.sh` to upload `cs112-*.pdf` to the VM.

#!/usr/bin/env zsh
# pdf-to-md.sh — convert PDF files to markdown using pdftotext + Claude
# Usage:
#   zsh scripts/pdf-to-md.sh <file.pdf>          # convert one file
#   zsh scripts/pdf-to-md.sh docs/human/pdf/     # convert all PDFs in a directory
#   zsh scripts/pdf-to-md.sh --delete            # convert all PDFs in docs/ and delete originals
#
# Requirements: pdftotext (brew install poppler) or python3 with pdfplumber
# Output: <same-name>.md next to the PDF, or in docs/human/ if converting from pdf/ subdir
#
# Convention (CLAUDE.md): #!/usr/bin/env zsh + set -euo pipefail
set -euo pipefail

DOCS_DIR="${DOCS_DIR:-$HOME/Documents/agentic-setup/docs/human}"
DELETE_AFTER=false
DRY_RUN=false

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --delete) DELETE_AFTER=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h)
      print "Usage: zsh scripts/pdf-to-md.sh [--delete] [--dry-run] [file.pdf | dir/]"
      print ""
      print "Options:"
      print "  --delete    Delete PDF files after successful conversion"
      print "  --dry-run   Show what would be converted without doing it"
      print ""
      print "If no file/dir given, converts all PDFs under docs/human/"
      exit 0
      ;;
    *) TARGET="$1"; shift ;;
  esac
done

TARGET="${TARGET:-$DOCS_DIR}"

# Check for pdftotext (preferred) or python3+pdfplumber fallback
if command -v pdftotext &>/dev/null; then
  EXTRACT_CMD="pdftotext"
elif command -v python3 &>/dev/null && python3 -c "import pdfplumber" 2>/dev/null; then
  EXTRACT_CMD="pdfplumber"
else
  print "ERROR: No PDF extractor found." >&2
  print "Install: brew install poppler   (provides pdftotext)" >&2
  print "     or: pip3 install pdfplumber" >&2
  exit 1
fi

extract_text() {
  local pdf="$1"
  if [[ "$EXTRACT_CMD" == "pdftotext" ]]; then
    pdftotext -layout "$pdf" - 2>/dev/null
  else
    python3 -c "
import pdfplumber, sys
with pdfplumber.open(sys.argv[1]) as pdf:
    for page in pdf.pages:
        text = page.extract_text()
        if text: print(text)
" "$pdf"
  fi
}

convert_pdf() {
  local pdf="$1"
  local basename="${pdf:t:r}"  # filename without extension
  local dir="${pdf:h}"          # parent directory

  # If PDF is in pdf/ subdir, output MD goes to parent docs/human/
  if [[ "$dir" == */pdf ]]; then
    local outdir="${dir:h}"
  else
    local outdir="$dir"
  fi

  local md_out="$outdir/${basename}.md"

  if [[ "$DRY_RUN" == true ]]; then
    print "  DRY-RUN: $pdf → $md_out"
    return 0
  fi

  # Skip if MD already exists and is newer than PDF
  if [[ -f "$md_out" ]] && [[ "$md_out" -nt "$pdf" ]]; then
    print "  SKIP (up to date): $md_out"
    return 0
  fi

  print "  Converting: ${pdf:t} → ${md_out:t}" >&2
  extract_text "$pdf" > "$md_out"

  if [[ ! -s "$md_out" ]]; then
    print "  ERROR: output is empty for $pdf" >&2
    rm -f "$md_out"
    return 1
  fi

  print "  OK: $md_out ($(wc -l < "$md_out") lines)"

  if [[ "$DELETE_AFTER" == true ]]; then
    rm "$pdf"
    print "  DELETED: $pdf"
  fi
}

# Find and convert PDFs
if [[ -f "$TARGET" && "$TARGET" == *.pdf ]]; then
  # Single file
  convert_pdf "$TARGET"
elif [[ -d "$TARGET" ]]; then
  # Directory — find all PDFs recursively
  print "Scanning: $TARGET"
  found=0
  while IFS= read -r pdf; do
    convert_pdf "$pdf"
    ((found++))
  done < <(find "$TARGET" -name "*.pdf" -type f | sort)
  print "Done. Processed $found PDF(s)."
else
  print "ERROR: '$TARGET' is not a PDF file or directory." >&2
  exit 1
fi

print '{"ok":true,"data":{"tool":"pdf-to-md"}}'

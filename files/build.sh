#!/usr/bin/env bash
# Build jdc_cv.pdf: generate jdc_master.bib, then pdflatex -> biber -> pdflatex x2.
#
# Usage:  ./build.sh            (from any directory)
#         ./build.sh --no-open  (don't open the PDF afterwards)

set -e

# Always run from the directory containing this script
cd "$(dirname "$0")"

# 1. Generate the master bibliography (any Python 3.6+ works; no packages needed)
if command -v python3 >/dev/null 2>&1; then
    PYTHON=python3
else
    PYTHON=python
fi
"$PYTHON" make_master_bib.py

# 2. Compile. -interaction=nonstopmode keeps pdflatex from stopping to wait for
#    input on an error (the cause of builds that hang or silently do nothing).
pdflatex -interaction=nonstopmode jdc_cv >/dev/null || true

# Set BIBER to use a different biber, e.g.  BIBER=~/bin/biber ./build.sh
BIBER="${BIBER:-biber}"
BIBER_OK=1
"$BIBER" jdc_cv 2>&1 | tee biber_output.txt || true
[ "${PIPESTATUS[0]}" -eq 0 ] || BIBER_OK=0
if [ "$BIBER_OK" -eq 0 ] && grep -q "lipo" biber_output.txt; then
    cat <<'MSG'

biber failed because macOS could not run "lipo" (needed by MacTeX's biber).
Fix (on this Mac, in Terminal):
  1. Install / repair the Xcode Command Line Tools:
       xcode-select --install
     If they are already installed, reset the developer path:
       sudo xcode-select -r
  2. Run ./build.sh again.
If it still fails, make an Apple Silicon-only copy of biber and use that:
       mkdir -p ~/bin
       lipo "$(realpath "$(which biber)")" -thin arm64 -output ~/bin/biber
       BIBER=~/bin/biber ./build.sh
MSG
    rm -f biber_output.txt
    exit 1
fi
rm -f biber_output.txt
[ "$BIBER_OK" -eq 1 ] || { echo "biber failed -- see jdc_cv.blg"; exit 1; }
pdflatex -interaction=nonstopmode jdc_cv >/dev/null || true
pdflatex -interaction=nonstopmode jdc_cv >/dev/null || true

if grep -q '^!' jdc_cv.log; then
    echo "LaTeX errors (see jdc_cv.log):"
    grep -A2 '^!' jdc_cv.log
    exit 1
fi
echo "Built jdc_cv.pdf"

# 3. Open the PDF
if [ "$1" != "--no-open" ]; then
    if command -v open >/dev/null 2>&1; then
        open jdc_cv.pdf            # macOS
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open jdc_cv.pdf        # Linux
    fi
fi

#!/bin/bash
# Batch download papers from Sci-Hub using the two-step method.
# Usage: ./batch_scihub_download.sh <dest_dir> <doi_list_file>
#
# doi_list_file format: one DOI per line, optionally with a short name:
#   10.1017/S0263574719001450 Meng2019_Aerial_Manipulator_Control
#   10.1109/LRA.2022.3196158  Krebs2022_Bimanual_Taxonomy
#
# Lines without a name use the DOI as filename.

set -e

DEST="${1:?Usage: $0 <dest_dir> <doi_list_file>}"
LIST="${2:?Usage: $0 <dest_dir> <doi_list_file>}"

mkdir -p "$DEST"

BASE="https://sci-hub.st"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

download_one() {
    local doi="$1"
    local name="$2"
    local out="$DEST/${name}.pdf"

    echo ">> $name ($doi)"

    # Step 1: Get PDF URL from sci-hub page
    local pdf_path
    pdf_path=$(curl -sL --connect-timeout 30 -H "User-Agent: $UA" \
        "${BASE}/${doi}" 2>/dev/null \
        | grep -oP 'pdf_url"\s*content="\K[^"]+')

    if [ -z "$pdf_path" ]; then
        echo "   ❌ NOT ON SCI-HUB"
        return 1
    fi

    # Step 2: Download PDF directly
    local status
    status=$(curl -sL -o "$out" -w "%{http_code}" \
        -H "User-Agent: Mozilla/5.0" \
        -H "Referer: ${BASE}/${doi}" \
        --connect-timeout 30 \
        "${BASE}${pdf_path}" 2>/dev/null)

    if [ "$status" = "200" ]; then
        local size=$(stat -c%s "$out" 2>/dev/null || echo "?")
        # Verify it's a real PDF
        if head -c5 "$out" | grep -q '%PDF-'; then
            echo "   ✅ $(numfmt --to=iec "$size" 2>/dev/null || echo "${size}B")"
        else
            echo "   ⚠️ Downloaded but not a valid PDF"
            return 1
        fi
    else
        echo "   ❌ HTTP $status"
        rm -f "$out"
        return 1
    fi
}

# Read DOI list
ok=0 fail=0
while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    doi=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{print $2}')
    [ -z "$name" ] && name=$(echo "$doi" | tr '/:' '_')

    if download_one "$doi" "$name"; then
        ((ok++))
    else
        ((fail++))
    fi
done < "$LIST"

echo "===== DONE: $ok OK, $fail failed ====="

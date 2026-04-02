#!/usr/bin/env bash
set -euo pipefail

SRC_BASE="$1"
DST_BASE="$2"
CP_FOLDER="$3"
STUDY_ID="$4"

# create folder if it doesn't exist
DST="${DST_BASE}/${CP_FOLDER}/${STUDY_ID}"

mkdir -p "${DST}"

echo "=== Copying ${CP_FOLDER} ==="

for d in "${SRC_BASE}/${CP_FOLDER}"/QTD*; do
    [ -d "$d" ] || continue
    qtd=$(basename "$d")

    echo "Processing $qtd..."

    rsync -av \
        --include="*.parquet" \
        --exclude="*" \
        "$d/" "${DST}/${qtd}/"


    src_count=$(find "$d" -maxdepth 1 -type f -name "*.parquet" | wc -l)
    dst_count=$(find "${DST}/${qtd}" -maxdepth 1 -type f -name "*.parquet" | wc -l)

    echo "  SRC: $src_count | DST: $dst_count"

    if [ "$src_count" -ne "$dst_count" ]; then
        echo "  ERROR: mismatch in $qtd"
        exit 1
    fi

    echo "  OK"
done

echo "=== ${CP_FOLDER} copy DONE ==="
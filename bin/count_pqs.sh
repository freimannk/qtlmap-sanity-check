#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

SUB_FOLDER="${@: -3:1}"
SELECTED_FOLDER="${@: -2:1}"
STUDY_ID="${@: -1:1}"

#all previous arguments = base dirs
BASE_DIRS=("${@:1:$#-3}")

OUTPUT_FILE="${STUDY_ID}_${SELECTED_FOLDER}_${SUB_FOLDER}.tsv"

> "$OUTPUT_FILE"

printf "dataset_id\tsubfolder\tcount\n" >> "$OUTPUT_FILE"

echo "Processing study: $STUDY_ID"
echo "Selected folder: $SELECTED_FOLDER"
echo "Subfolder: $SUB_FOLDER"
echo "Base dirs:"
printf "  - %s\n" "${BASE_DIRS[@]}"
echo ""

for BASE_DIR in "${BASE_DIRS[@]}"; do

    SPEC_BASE_DIR="${BASE_DIR}/${SELECTED_FOLDER}"

    if [ ! -d "$SPEC_BASE_DIR" ]; then
        echo "WARNING: Missing $SPEC_BASE_DIR"
        continue
    fi

    #Loop QTD dirs
    for dir in "$SPEC_BASE_DIR"/QTD*; do
        dirname=$(basename "$dir")

        if [ -d "$dir/${SUB_FOLDER}" ]; then
            count=$(find "$dir/${SUB_FOLDER}" -maxdepth 1 -type f -name "*.parquet" -printf '.' | wc -c)
            printf "%s\t%s\t%s\n" "$dirname" "$SUB_FOLDER" "$count" >> "$OUTPUT_FILE"
        else
            printf "%s\t%s\tNA\n" "$dirname" "$SUB_FOLDER" >> "$OUTPUT_FILE"
        fi
    done

done

echo ""
echo "Done. Results saved in $OUTPUT_FILE"
#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

if (( $# < 3 )); then
    echo "Usage: $0 <BASE_DIR...> <SELECTED_FOLDER> <STUDY_ID>"
    echo "Example:"
    echo "  $0 GAinS_other GAinS_ge sumstats GAinS_other"
    echo "  $0 GAinS_other GAinS_ge susie GAinS_other"
    exit 1
fi

SELECTED_FOLDER="${@: -2:1}"
STUDY_ID="${@: -1:1}"
BASE_DIRS=("${@:1:$#-2}")

OUTPUT_FILE="${STUDY_ID}_${SELECTED_FOLDER}_log.tsv"

case "$SELECTED_FOLDER" in
    *sumstats*)
        MODE="sumstats"
        ;;
    *susie*)
        MODE="susie"
        ;;
    *)
        echo "ERROR: SELECTED_FOLDER must contain either 'sumstats' or 'susie'"
        exit 1
        ;;
esac

has_file() {
    local dir="$1"
    local pattern="$2"
    local files=( "$dir"/$pattern )

    (( ${#files[@]} > 0 ))
}

required_files_present() {
    local dir="$1"

    case "$MODE" in
        sumstats)
            has_file "$dir" "*.permuted.parquet" &&
            has_file "$dir" "*.cc.parquet"
            ;;
        susie)
            has_file "$dir" "*.lbf_variable.parquet" &&
            has_file "$dir" "*.credible_sets.parquet"
            ;;
    esac
}

# Write TSV header
if [ "$MODE" = "sumstats" ]; then
    printf "base_dir\tselected_folder\tdataset_id\trequired_files_present\tconcatenated_sumstats_file\n" > "$OUTPUT_FILE"
else
    printf "base_dir\tselected_folder\tdataset_id\trequired_files_present\n" > "$OUTPUT_FILE"
fi

echo "Processing study: $STUDY_ID"
echo "Selected folder: $SELECTED_FOLDER"
echo "Mode: $MODE"
echo "Output TSV log: $OUTPUT_FILE"
echo ""

for BASE_DIR in "${BASE_DIRS[@]}"; do
    SPEC_BASE_DIR="${BASE_DIR}/${SELECTED_FOLDER}"

    if [ ! -d "$SPEC_BASE_DIR" ]; then
        echo "WARNING: Missing $SPEC_BASE_DIR"

        if [ "$MODE" = "sumstats" ]; then
            printf "%s\t%s\tNA\tfalse\tNA\n" \
                "$BASE_DIR" "$SELECTED_FOLDER" >> "$OUTPUT_FILE"
        else
            printf "%s\t%s\tNA\tfalse\n" \
                "$BASE_DIR" "$SELECTED_FOLDER" >> "$OUTPUT_FILE"
        fi

        continue
    fi

    qtd_dirs=( "$SPEC_BASE_DIR"/QTD* )

    if (( ${#qtd_dirs[@]} == 0 )); then
        echo "WARNING: No QTD* directories found in $SPEC_BASE_DIR"

        if [ "$MODE" = "sumstats" ]; then
            printf "%s\t%s\tNA\tfalse\tNA\n" \
                "$BASE_DIR" "$SELECTED_FOLDER" >> "$OUTPUT_FILE"
        else
            printf "%s\t%s\tNA\tfalse\n" \
                "$BASE_DIR" "$SELECTED_FOLDER" >> "$OUTPUT_FILE"
        fi

        continue
    fi

    for dir in "${qtd_dirs[@]}"; do
        [ -d "$dir" ] || continue

        dataset_id=$(basename "$dir")

        if required_files_present "$dir"; then
            required_ok="true"
        else
            required_ok="false"
        fi

        if [ "$MODE" = "sumstats" ]; then
            if has_file "$dir" "*.all.parquet"; then
                all_present="true"
            else
                all_present="false"
            fi

            printf "%s\t%s\t%s\t%s\t%s\n" \
                "$BASE_DIR" \
                "$SELECTED_FOLDER" \
                "$dataset_id" \
                "$required_ok" \
                "$all_present" >> "$OUTPUT_FILE"
        else
            printf "%s\t%s\t%s\t%s\n" \
                "$BASE_DIR" \
                "$SELECTED_FOLDER" \
                "$dataset_id" \
                "$required_ok" >> "$OUTPUT_FILE"
        fi
    done
done

echo ""
echo "Done."
echo "TSV log saved in $OUTPUT_FILE"
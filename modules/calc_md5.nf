process calculate_md5 {
    tag "${study_id}"
    publishDir "${params.outdir}/md5", mode: 'copy'

    input:
    tuple val(study_id), val(location_paths)

    output:
    path("${study_id}_md5.tsv")

    script:
    """
    set -euo pipefail

     OUTPUT_FILE="${study_id}_md5.tsv"

    # header
    echo -e "file_path\tmd5" > \$OUTPUT_FILE

    # loop over all base directories
    for BASE in ${location_paths.join(' ')}; do

        for TYPE in sumstats susie susie_batches; do

            TARGET_DIR="\${BASE}/\${TYPE}/${study_id}"


echo "-----------------------------"
echo "DEBUG: BASE        = \$BASE"
echo "DEBUG: TYPE        = \$TYPE"
echo "DEBUG: STUDY_ID    = $study_id"
echo "DEBUG: TARGET_DIR  = \$TARGET_DIR"
echo "-----------------------------"

if [ -d "\$TARGET_DIR" ]; then
    echo "Scanning directory: \$TARGET_DIR"

    # List all files for debugging
    echo "Files found:"
    find "\$TARGET_DIR" -type f -print

    # Calculate md5
    find "\$TARGET_DIR" -type f | while read FILE; do
        HASH=\$(md5sum "\$FILE" | awk '{print \$1}')
        REL_PATH=\$(realpath --relative-to="\$BASE" "\$FILE")
        echo -e "\${REL_PATH}\t\${HASH}" >> \$OUTPUT_FILE

        # Debug print for each file processed
        echo "Processed: \$FILE -> \$REL_PATH : \$HASH"
    done
else
    echo "Skipping missing directory: \$TARGET_DIR"
fi



        done

    done

    touch done_${study_id}.log
    """
}
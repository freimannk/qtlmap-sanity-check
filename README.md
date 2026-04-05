# qtlmap output checking and copying/publishing pipeline

## Pipeline overview

The pipeline has two main main entries:

### `check_qtlmap_output`
Runs on:
- `<src_path>`

Generates:
- parquet corruption reports
- subfolder parquet count summaries - `sumstats/all, susie_batches/{full/cs/lbf}`
- credible set summary statistics

Does not generate:
- copied files
- published destination directories
- MD5 checksums

### `publish_qtlmap_output`
Runs on:
- `<src_path> -> <dest_path>`

Generates:
- copied/published files
- published parquet validation reports
- MD5 checksum tables

---

## Input format

The input must be a tab-separated file with header.

### Minimal format for source validation
Used by the `check_qtlmap_output` entry:

```tsv
study_id	src_path
QTS001T	/path/to/qtlmap_ge
QTS001T	/path/to/qtlmap_exon
QTS002T	/path/to/qtlmap_ge
```
 without lagging `/`

Used by the `publish_qtlmap_output` entry:

```tsv
study_id	src_path	dest_path
QTS000055	/path/to/qtlmap_out1_ge	/path/to/qtlmap_new_dest
QTS000055	/path/to/qtlmap_out2_exon	/path/to/qtlmap_new_dest
QTS000055	/path/to/qtlmap_out3_other	/path/to/qtlmap_new_dest
```
without lagging `/`

Expected source directory structure
```tsv
<src_path>/
├── sumstats/
│   └── QTD.../
│       └── *.parquet
├── susie/
│   └── QTD.../
│       └── *.parquet
└── susie_batches/
    └── QTD.../
        ├── cs/
        │    └── *.parquet
        ├── full/
        │   └── *.parquet
        └── lbf/
            └── *.parquet
```

Expected final destination directory structure after copying/publishing

After the publish workflow runs, the destination directory is expected to look like this:

```text
<dest_path>/
├── sumstats/
│   └── <study_id>/
│       └── QTD.../
│           └── *.parquet
├── susie/
│   └── <study_id>/
│       └── QTD.../
│           └── *.parquet
└── susie_batches/
    └── <study_id>/
        └── QTD.../
            └── QTD....full_susie.parquet
```

## How to run the workflow:

To run the whole workflow:

```sh
nextflow run main.nf -profile tartu_hpc -resume --input input.tsv --outdir my_results
```

To run only qtlmap output validation and cs statistics:
```sh
nextflow run main.nf -profile tartu_hpc -resume -entry check_qtlmap_output --input input.tsv --outdir my_results
```

To run only qtlmap output copying/publishing:
```sh
nextflow run main.nf -profile tartu_hpc -resume -entry publish_qtlmap_output --input input.tsv --outdir my_results
```

## Output
### For qtlmap output validation:
The workflow scans parquet files under the grouped source paths for each study_id.
The pipeline continues even when corrupted parquet files are found (`errorStrategy { task.exitStatus == 10 ? 'ignore' : 'terminate' }`).
This is shown by failed `detect_corrupted_files` process.
Validation reports are written into
`<outdir>/validation/scanned_pqs_raports/`
For each study the following files are created:
- `output_<study_id>_scanned_pqs_raport.log`
- `output_<study_id>_scanned_pqs_raport.tsv`

Outputs are written into:

`<outdir>/validation/subfolder_file_counts/<study_id>/`

The following count files are generated:

- `<study_id>_sumstats_batches_all.tsv`
- `<study_id>_susie_batches_cs.tsv`
- `<study_id>_susie_batches_full.tsv`
- `<study_id>_susie_batches_lbf.tsv`


The workflow also scans credible set parquet files from:
`<src_path>/susie/QTD*/*.credible_sets.parquet`.
For each detected dataset it generates summary tables and plots.
Outputs are written into:
`<outdir>/cs_stats/<study_id>/`


### For copying:

sumstats files are copied from:
`<src_path>/sumstats/QTD*/` into `<dest_path>/sumstats/<study_id>/QTD*/`
susie files are copied from `<src_path>/susie/QTD*/`
into `<dest_path>/susie/<study_id>/QTD*/`

 if params.concate_full_susie_batches = true, then all parquet files in:
`<src_path>/susie_batches/QTDXXXX/full/` are concatenated into one file:
`QTDXXXX.full_susie.parquet`
and published into:
`<dest_path>/susie_batches/<study_id>/QTDXXXX/`

MD5 checksums are generated per study_id.
For each unique destination base directory the workflow scans:
- `<dest>/sumstats/<study_id>`
- `<dest>/susie/<study_id>`
- `<dest>/susie_batches/<study_id>`
and writes a TSV file:
`<study_id>_md5.tsv`
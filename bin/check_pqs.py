#!/usr/bin/env python

import os
import duckdb
import argparse
import sys

EXIT_CORRUPT_PARQUET = 10


def find_parquet_files(root):
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            if fn.endswith(".parquet"):
                yield os.path.join(dirpath, fn)


def validate_parquet(path, con):
    try:
        con.execute(f"SELECT file_name FROM parquet_metadata('{path}');")
        return True
    except Exception:
        return False


def scan_directories(roots, output_file_name):
    con = duckdb.connect()

    total = 0
    bad_files = []

    print(f"Scanning directories:\n")
    for root in roots:
        print(f"  - {root}")
    print("\n")
    for root in roots:
        for fpath in find_parquet_files(root):
            total += 1
            if not validate_parquet(fpath, con):
                bad_files.append(fpath)

    con.close()

    # Summary
    summary_lines = [
        "=== SUMMARY ===",
        f"Total parquet files scanned: {total}",
        f"Corrupted files found:       {len(bad_files)}",
    ]

    if bad_files:
        summary_lines.append("\n=== CORRUPTED FILES ===")
        summary_lines.extend(bad_files)
    else:
        summary_lines.append("\nAll files are valid ✅")

    # Write log
    log_file = f"{output_file_name}.log"
    with open(log_file, "w") as f:
        f.write("\n".join(summary_lines))

    # Write TSV
    tsv_file = f"{output_file_name}.tsv"
    with open(tsv_file, "w") as f:
        f.write("file_path\n")
        for bf in bad_files:
            f.write(f"{bf}\n")

    print(f"\nLog saved to: {log_file}")
    print(f"Corrupted file list saved to: {tsv_file}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Scan multiple directories for parquet files and report corrupted ones using DuckDB."
    )
    parser.add_argument(
        "-d", "--scanned_dirs",
        required=True,
        nargs="+",
        help="One or more directories to scan"
    )
    parser.add_argument(
        "-o", "--output_file_name",
        required=True,
        help="Output file name prefix"
    )
    args = parser.parse_args()
    scan_directories(args.scanned_dirs, args.output_file_name)
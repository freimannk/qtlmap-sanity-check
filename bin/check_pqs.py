#!/usr/bin/env python


import os
import duckdb
import argparse

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

def scan_directory(root:str, output_file_name:str):
    con = duckdb.connect()
    total = 0
    bad_files = []

    print(f"Scanning directory: {root}\n")

    for fpath in find_parquet_files(root):
        total += 1
        if not validate_parquet(fpath, con):
            bad_files.append(fpath)

    con.close()

    with open(f"{output_file_name}.txt", "w") as f:
        f.write("\n".join(bad_files))
    print(f"\n Corrupted file list saved to: {output_file_name}.txt")

    print("\n=== SUMMARY ===")
    print(f"Total parquet files scanned: {total}")
    print(f"Corrupted files found:       {len(bad_files)}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Join filtered run_susie with nominal parquet files using DuckDB.")
    parser.add_argument('-d', '--scanned_dir', required=True, type=str, help="Scanned directory")
    parser.add_argument('-o', '--output_file_name', required=True, help="Output file name")
    args = parser.parse_args()
    scan_directory(args.scanned_dir, args.output_file_name)

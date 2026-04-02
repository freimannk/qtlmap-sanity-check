#!/usr/bin/env python

import duckdb
import argparse
import os

def concatenate_parquet_dir(input_dir, output_file, memory_limit, threads):
    memory_limit = f"{float(memory_limit) * 0.85:.1f}"

    # DuckDB reads all parquet files in directory via glob
    query = f"""
        SET memory_limit='{memory_limit}GB';
        PRAGMA threads={threads};
        COPY (
            SELECT * FROM read_parquet('{input_dir}/*.parquet')
            ORDER BY chromosome, position
        ) TO '{output_file}' (FORMAT PARQUET);
    """

    con = duckdb.connect()
    con.execute(query)
    con.close()

    print(f"Merged {input_dir} → {output_file}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Merge parquet files in a directory using DuckDB.")

    parser.add_argument("-i", "--input_dir", required=True, help="Path to full/ directory")
    parser.add_argument("-o", "--output_file", required=True, help="Output parquet file")
    parser.add_argument("-m", "--memory_limit", required=True, help="Memory in GB")
    parser.add_argument("-t", "--threads", default=4, type=int, help="Number of threads")

    args = parser.parse_args()

    # Optional safety check
    if not os.path.isdir(args.input_dir):
        raise ValueError(f"Input directory does not exist: {args.input_dir}")

    concatenate_parquet_dir(
        args.input_dir,
        args.output_file,
        args.memory_limit,
        args.threads
    )
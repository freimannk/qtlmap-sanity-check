#!/usr/bin/env python3

import argparse
import pandas as pd
from statsmodels.stats.multitest import multipletests


def main():
    parser = argparse.ArgumentParser(
        description="Calculate significant QTL hits from one parquet permutation file."
    )

    parser.add_argument(
        "-d", "--dataset",
        required=True,
        help="Dataset name, for example ge, exon, leafcutter, majiq."
    )

    parser.add_argument(
        "-p", "--permutation-file",
        required=True,
        help="Permutation parquet file."
    )

    parser.add_argument(
        "-o", "--output",
        required=True,
        help="Output summary TSV."
    )

    parser.add_argument(
        "--alpha",
        type=float,
        default=0.05,
        help="FDR threshold. Default: 0.05"
    )

    args = parser.parse_args()

    df = pd.read_parquet(args.permutation_file)

    if "p_beta" not in df.columns:
        raise ValueError("Input parquet file does not contain column: p_beta")

    df["p_beta"] = pd.to_numeric(df["p_beta"], errors="coerce")
    df = df.dropna(subset=["p_beta"])
    df = df[df["p_beta"].between(0, 1)].copy()

    if "molecular_trait_object_id" in df.columns:
        df = (
            df.sort_values("p_beta")
              .drop_duplicates("molecular_trait_object_id", keep="first")
        )

    df["qvalue"] = multipletests(df["p_beta"], method="fdr_bh")[1]

    tested_traits = len(df)
    significant_hits = int((df["qvalue"] < args.alpha).sum())

    summary = pd.DataFrame([
        {
            "dataset": args.dataset,
            "fdr_method": "fdr_bh",
            "alpha": args.alpha,
            "tested_traits": tested_traits,
            "significant_hits": significant_hits,
        }
    ])

    summary.to_csv(args.output, sep="\t", index=False)


if __name__ == "__main__":
    main()
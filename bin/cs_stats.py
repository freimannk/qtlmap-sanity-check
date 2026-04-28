#!/usr/bin/env python3

import argparse

import duckdb
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd


def query_cs(parquet_file, pip_threshold):
    con = duckdb.connect()

    df_cs = con.execute(f"""
        SELECT 
            molecular_trait_id,
            cs_id, 
            COUNT(*) AS snp_count, 
            MAX(pip) AS max_pip
        FROM '{parquet_file}'
        GROUP BY molecular_trait_id, cs_id
    """).fetchdf()

    summary = con.execute(f"""
        SELECT
            COUNT(*) AS total_cs,
            COALESCE(SUM(CASE WHEN max_pip > {pip_threshold} THEN 1 ELSE 0 END), 0)
                AS cs_max_pip_above_threshold,
            COALESCE(SUM(CASE WHEN max_pip > 0.5 AND max_pip <= {pip_threshold} THEN 1 ELSE 0 END), 0)
                AS cs_max_pip_between_0_5_and_threshold,
            COALESCE(SUM(CASE WHEN max_pip <= 0.5 THEN 1 ELSE 0 END), 0)
                AS cs_max_pip_at_or_below_0_5
        FROM (
            SELECT molecular_trait_id, cs_id, MAX(pip) AS max_pip
            FROM '{parquet_file}'
            GROUP BY molecular_trait_id, cs_id
        )
    """).fetchdf()

    df_molecular_trait_id = con.execute(f"""
        SELECT 
            molecular_trait_id,
            COUNT(DISTINCT cs_id) AS n_cs
        FROM '{parquet_file}'
        GROUP BY molecular_trait_id
    """).fetchdf()

    con.close()

    print("\nCS-level data:")
    print(df_cs.head())

    print("\nSummary:")
    print(summary)

    print("\nCS per molecular_trait_id:")
    print(df_molecular_trait_id.head())

    return df_cs, df_molecular_trait_id, summary


# -------------------------
# PLOTS
# -------------------------

def plot_all_cs(df, out):
    plt.figure(figsize=(8, 5))
    sns.histplot(df["max_pip"], bins=30)
    plt.xlabel("Max PIP per CS")
    plt.ylabel("Number of CS")
    plt.title("All credible sets")
    plt.tight_layout()
    plt.savefig(f"{out}_all_cs.png")
    plt.close()


def plot_cs_size(df, out):
    plt.figure(figsize=(8, 5))
    sns.histplot(df["snp_count"], bins=30)
    plt.xlabel("CS size (number of SNPs)")
    plt.ylabel("Number of CS")
    plt.title("Credible set size distribution")
    plt.tight_layout()
    plt.savefig(f"{out}_cs_size.png")
    plt.close()


def plot_cs_per_molecular_trait_id(df_molecular_trait_id, out):
    plt.figure(figsize=(8, 5))
    sns.histplot(df_molecular_trait_id["n_cs"], bins=20)
    plt.xlabel("Number of CS per molecular_trait_id")
    plt.ylabel("Number of molecular_trait_id")
    plt.title("Signals per molecular_trait_id")
    plt.tight_layout()
    plt.savefig(f"{out}_cs_per_molecular_trait_id.png")
    plt.close()


# -------------------------
# SAVE OUTPUTS
# -------------------------

def add_id_columns(df, study_id, dataset):
    df = df.copy()
    df.insert(0, "dataset", dataset)
    df.insert(0, "study_id", study_id)
    return df


def describe_as_one_row(series, prefix):
    stats = series.describe()

    return {
        f"{prefix}_count": stats.get("count", pd.NA),
        f"{prefix}_mean": stats.get("mean", pd.NA),
        f"{prefix}_std": stats.get("std", pd.NA),
        f"{prefix}_min": stats.get("min", pd.NA),
        f"{prefix}_q25": stats.get("25%", pd.NA),
        f"{prefix}_median": stats.get("50%", pd.NA),
        f"{prefix}_q75": stats.get("75%", pd.NA),
        f"{prefix}_max": stats.get("max", pd.NA),
    }


def save_summary(summary, study_id, dataset, pip_threshold, out):
    summary = summary.copy()
    summary.insert(0, "pip_threshold", pip_threshold)
    summary = add_id_columns(summary, study_id, dataset)

    summary.to_csv(f"{out}_summary.tsv", sep="\t", index=False)


def save_cs_size_stats(df_cs, study_id, dataset, out):
    row = describe_as_one_row(df_cs["snp_count"], "cs_size")
    stats_df = pd.DataFrame([row])
    stats_df = add_id_columns(stats_df, study_id, dataset)

    stats_df.to_csv(f"{out}_cs_size_stats.tsv", sep="\t", index=False)


def save_molecular_trait_id_stats(df_molecular_trait_id, study_id, dataset, out):
    row = describe_as_one_row(df_molecular_trait_id["n_cs"], "cs_per_molecular_trait")
    stats_df = pd.DataFrame([row])
    stats_df = add_id_columns(stats_df, study_id, dataset)

    stats_df.to_csv(f"{out}_cs_per_molecular_trait_id_stats.tsv", sep="\t", index=False)


# -------------------------
# MAIN
# -------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Generate credible set statistics and plots from one parquet file."
    )

    parser.add_argument("-s", "--study-id", required=True, help="Study ID")
    parser.add_argument("-d", "--dataset", required=True, help="Dataset ID")
    parser.add_argument("-p", "--parquet", required=True, help="Input CS parquet file")
    parser.add_argument("-t", "--pip-threshold", type=float, required=True, help="PIP threshold")

    args = parser.parse_args()

    study_id = args.study_id
    dataset = args.dataset
    parquet = args.parquet
    pip_threshold = args.pip_threshold

    if pip_threshold <= 0.5 or pip_threshold > 1:
        raise ValueError("pip_threshold must be > 0.5 and <= 1.")

    print(f"Processing study: {study_id}")
    print(f"Processing dataset: {dataset}")
    print(f"Input file: {parquet}")
    print(f"PIP threshold: {pip_threshold}")

    df_cs, df_molecular_trait_id, summary = query_cs(parquet, pip_threshold)

    plot_all_cs(df_cs, dataset)
    plot_cs_size(df_cs, dataset)
    plot_cs_per_molecular_trait_id(df_molecular_trait_id, dataset)

    save_summary(summary, study_id, dataset, pip_threshold, dataset)
    save_cs_size_stats(df_cs, study_id, dataset, dataset)
    save_molecular_trait_id_stats(df_molecular_trait_id, study_id, dataset, dataset)

    print("\nOutputs generated:")
    print(f"- {dataset}_all_cs.png")
    print(f"- {dataset}_cs_size.png")
    print(f"- {dataset}_cs_per_molecular_trait_id.png")
    print(f"- {dataset}_summary.tsv")
    print(f"- {dataset}_cs_size_stats.tsv")
    print(f"- {dataset}_cs_per_molecular_trait_id_stats.tsv")


if __name__ == "__main__":
    main()
#!/usr/bin/env python

import duckdb
import matplotlib.pyplot as plt
import seaborn as sns
import argparse



def query_cs(parquet_file, PIP_THRESHOLD):
    con = duckdb.connect()

    # CS-level stats
    df_cs = con.execute(f"""
        SELECT 
            molecular_trait_id,
            cs_id, 
            COUNT(*) AS snp_count, 
            MAX(pip) AS max_pip
        FROM '{parquet_file}'
        GROUP BY molecular_trait_id, cs_id
    """).fetchdf()

    # Summary stats
    summary = con.execute(f"""
        SELECT
            COUNT(*) AS total_cs,
            SUM(CASE WHEN max_pip > {PIP_THRESHOLD} THEN 1 ELSE 0 END) AS strong_cs,
            SUM(CASE WHEN max_pip > 0.5 THEN 1 ELSE 0 END) AS medium_cs,
            SUM(CASE WHEN max_pip <= 0.5 THEN 1 ELSE 0 END) AS weak_cs
        FROM (
            SELECT molecular_trait_id, cs_id, MAX(pip) AS max_pip
            FROM '{parquet_file}'
            GROUP BY molecular_trait_id, cs_id
        )
    """).fetchdf()

    # CS per molecular_trait_id
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

def save_summary(summary, dataset_id, out):
    summary["dataset_id"] = dataset_id
    summary.to_csv(f"{out}_summary.tsv", sep="\t", index=False)


def save_cs_size_stats(df, out):
    stats = df["snp_count"].describe()
    stats.to_csv(f"{out}_cs_size_stats.tsv", sep="\t")


def save_molecular_trait_id_stats(df_molecular_trait_id, out):
    stats = df_molecular_trait_id["n_cs"].describe()
    stats.to_csv(f"{out}_cs_per_molecular_trait_id_stats.tsv", sep="\t")


# -------------------------
# MAIN
# -------------------------

def main():
    parser = argparse.ArgumentParser(description="Merge parquet files in a directory using DuckDB.")

    parser.add_argument("-d", "--dataset", required=True, help="dataset_id")
    parser.add_argument("-p", "--parquet", required=True, help="Input cs parquet file")
    parser.add_argument("-t", "--pip_threshold",  type=float, required=True, help="Pip threshold")

    args = parser.parse_args()


    dataset_id = args.dataset
    parquet = args.parquet
    PIP_THRESHOLD = args.pip_threshold

    print(f"Processing dataset: {dataset_id}")
    print(f"Input file: {parquet}")

    df_cs, df_molecular_trait_id, summary = query_cs(parquet,PIP_THRESHOLD)

    plot_all_cs(df_cs, dataset_id)
    plot_cs_size(df_cs, dataset_id)
    plot_cs_per_molecular_trait_id(df_molecular_trait_id, dataset_id)

    save_summary(summary, dataset_id, dataset_id)
    save_cs_size_stats(df_cs, dataset_id)
    save_molecular_trait_id_stats(df_molecular_trait_id, dataset_id)

    print("\nOutputs generated:")
    print(f"- {dataset_id}_all_cs.png")
    print(f"- {dataset_id}_cs_size.png")
    print(f"- {dataset_id}_cs_per_molecular_trait_id.png")
    print(f"- {dataset_id}_summary.tsv")
    print(f"- {dataset_id}_cs_size_stats.tsv")
    print(f"- {dataset_id}_cs_per_molecular_trait_id_stats.tsv")


if __name__ == "__main__":
    main()
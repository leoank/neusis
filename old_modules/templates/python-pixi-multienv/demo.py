#!/usr/bin/env python
"""
Progressive Python Demo: Shows the boundary between pure Nix and uv approaches.
Runs as far as it can, failing gracefully at the boundary.
"""

import sys
import warnings
warnings.filterwarnings("ignore", category=FutureWarning)

print("=" * 60)
print("Python Environment Capability Demo")
print("=" * 60)

# Level 1: Standard data science (all in nixpkgs)
print("\n[1] Standard data science packages:")
try:
    import numpy as np
    import pandas as pd
    import matplotlib.pyplot as plt
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.model_selection import train_test_split

    # Actually run something
    np.random.seed(42)
    X = np.random.randn(200, 10)
    y = (X[:, 0] + X[:, 1] > 0).astype(int)

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)
    clf = RandomForestClassifier(n_estimators=10, random_state=42)
    clf.fit(X_train, y_train)
    accuracy = clf.score(X_test, y_test)

    # Create a simple plot (in-memory only)
    plt.figure(figsize=(6, 3))
    plt.hist([X[y==0, 0], X[y==1, 0]], alpha=0.5, label=['Class 0', 'Class 1'])
    plt.close()

    print(f"✓ numpy {np.__version__}, pandas {pd.__version__}, sklearn loaded")
    print(f"✓ Trained RandomForest: {accuracy:.1%} accuracy")
    print(f"✓ Plotting works (matplotlib)")
except ImportError as e:
    print(f"✗ Failed: {e}")
    sys.exit(1)

# Level 2: Common tools (actually in nixpkgs!)
print("\n[2] Common Python tools (in nixpkgs):")
try:
    import typer
    from loguru import logger
    import duckdb
    import snakemake

    # Actually use them
    logger.info("Loguru logging works!")

    # DuckDB query
    conn = duckdb.connect(':memory:')
    result = conn.execute("SELECT 'DuckDB' as db, 1+1 as sum").fetchall()

    print(f"✓ typer {typer.__version__}, loguru, snakemake {snakemake.__version__}")
    print(f"✓ duckdb {duckdb.__version__}: {result[0]} (copairs requires <1.4.0)")
except ImportError as e:
    print(f"✗ Failed: {e}")

# Level 3: PyPI-only packages (NOT in nixpkgs)
print("\n[3] PyPI-only packages:")
try:
    import upsetplot
    from upsetplot import plot

    # Create upset plot data
    data_dict = {
        'Set A': [1, 1, 0, 1, 0],
        'Set B': [1, 0, 1, 1, 0],
        'Set C': [0, 0, 1, 1, 1]
    }
    upset_df = pd.DataFrame(data_dict).astype(bool)
    counts = upset_df.value_counts()

    # Create the plot (in-memory only)
    plt.figure(figsize=(6, 3))
    plot(counts, show_counts=True)
    plt.close()

    print(f"✓ upsetplot {upsetplot.__version__} works!")
    print(f"✓ Created upset plot with {len(counts)} intersections")
except ImportError as e:
    print(f"✗ upsetplot not available (not in nixpkgs, needs uv)")

# Level 4: Git sources (impossible with pure Nix)
print("\n[4] Git-sourced packages:")

# Try copairs-runner first (works with numpy 2.x in pixi)
copairs_works = False
jump_smiles_works = False

try:
    import copairs
    from copairs.map import mean_average_precision
    assert callable(mean_average_precision), "copairs.map.mean_average_precision not callable"
    copairs_works = True
except ImportError:
    pass

# Try jump_smiles (requires numpy<2, conflicts with RAPIDS)
try:
    import jump_smiles
    from jump_smiles.standardize_smiles import StandardizeMolecule
    assert hasattr(StandardizeMolecule, 'run'), "StandardizeMolecule missing run method"
    jump_smiles_works = True
except ImportError:
    pass

if copairs_works and jump_smiles_works:
    print(f"✓ All git packages work!")
    print(f"  jump_smiles.StandardizeMolecule available")
    print(f"  copairs.map.mean_average_precision available")
elif copairs_works:
    print(f"✓ copairs works (compatible with numpy {np.__version__})")
    print(f"✗ jump_smiles unavailable (requires numpy<2, conflicts with RAPIDS)")
elif jump_smiles_works:
    print(f"✓ jump_smiles works")
    print(f"✗ copairs unavailable")
else:
    print(f"✗ Git sources not available")
    print("  These require uv approach - cannot install from git in pure Nix")

# Level 5: GPU/RAPIDS packages (needs CUDA and conda ecosystem)
print("\n[5] GPU/RAPIDS packages:")
try:
    import anndata
    import cupy as cp
    import rapids_singlecell as rsc

    print(f"✓ anndata {anndata.__version__} imported")
    print(f"✓ cupy {cp.__version__} imported")

    # Simple GPU computation
    gpu_array = cp.random.randn(100, 100)
    result = cp.sum(gpu_array)
    print(f"✓ GPU computation works: sum = {float(result):.2f}")

    # Create a small AnnData object and test rapids_singlecell
    np.random.seed(42)
    X = np.random.randn(100, 50)
    adata = anndata.AnnData(X=X)

    # Try PCA (might use CPU if GPU not available)
    rsc.tl.pca(adata, n_comps=10)
    print(f"✓ rapids_singlecell PCA: reduced to shape {adata.obsm['X_pca'].shape}")

except ImportError as e:
    print(f"✗ GPU/RAPIDS not available: {e}")
    print("  These require pixi approach - need CUDA and conda packages")
except Exception as e:
    print(f"✗ GPU/RAPIDS runtime error: {e}")

# Summary
print("\n" + "=" * 60)
print("Demo complete! Environment capabilities:")
print("- Levels 1-2: Standard packages (numpy, pandas, sklearn, etc.)")
print("- Level 3: PyPI-only packages (upsetplot) - needs uv or pixi")
print("- Level 4: Git sources (jump_smiles) - needs uv only")
print("- Level 5: GPU/RAPIDS (cupy, rapids_singlecell) - needs pixi")
print("=" * 60)
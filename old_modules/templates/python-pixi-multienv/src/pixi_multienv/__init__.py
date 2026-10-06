"""
Pixi Multi-Environment Demo

Demonstrates handling incompatible dependencies using pixi's environment feature.

Problem: RAPIDS requires numpy ≥2, jump-smiles requires numpy <2
Solution: Multiple environments in one pyproject.toml

Environments:
    rapids: GPU/RAPIDS workloads (numpy 2.x)
    smiles: Chemical standardization (numpy 1.x)
"""

__version__ = "0.1.0"

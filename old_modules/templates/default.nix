{
  flake = {
    path = ./flake;
    description = "Generic flake";
  };

  flakevirt = {
    path = ./flakevirt;
    description = "Generic flake";
  };

  fhsflake = {
    path = ./fhsflake;
    description = "Generic fhs flake";
  };

  fhspythonml = {
    path = ./fhspythonml;
    description = "FHS Python ML environment with CUDA support and Docker/Arion integration";
  };

  python = {
    path = ./python;
    description = "Basic Python flake environment";
  };

  pythonml = {
    path = ./pythonml;
    description = "Python ML environment with notebook support and Docker/Arion integration";
  };

  python-nix = {
    path = ./python-nix;
    description = "CSLab: Pure Nix Python environment (nixpkgs only, max reproducibility)";
  };

  python-uv = {
    path = ./python-uv;
    description = "CSLab: Python with uv (PyPI + git sources, default for pure Python)";
  };

  python-pixi = {
    path = ./python-pixi;
    description = "CSLab: Python with pixi (conda packages for GPU/RAPIDS, single environment)";
  };

  python-pixi-multienv = {
    path = ./python-pixi-multienv;
    description = "CSLab: Python with pixi (multiple environments for conflicting dependencies)";
  };

  rust = {
    path = ./rust;
    description = "Generic rust environment";
  };

}

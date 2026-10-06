{
  inputs,
  outputs,
  ...
}:
{
  # For every flake input, aliases 'pkgs.inputs.${flake}' to
  # 'inputs.${flake}.packages.${pkgs.stdenv.hostPlatform.system}' or
  # 'inputs.${flake}.legacyPackages.${pkgs.stdenv.hostPlatform.system}'
  flake-inputs = final: _: {
    inputs = builtins.mapAttrs (
      _: flake:
      let
        legacyPackages = (flake.legacyPackages or { }).${final.stdenv.hostPlatform.system} or { };
        packages = (flake.packages or { }).${final.stdenv.hostPlatform.system} or { };
      in
      if legacyPackages != { } then legacyPackages else packages
    ) inputs;
  };

  # Adds pkgs.unstable == inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}
  unstable =
    final: _:
    let
      upkgs = import inputs.nixpkgs-unstable {
        system = final.stdenv.hostPlatform.system;
        config.allowUnfree = true;
        config.cudaSupport = true;
      };
    in
    {
      unstable = upkgs;
    };

  # Adds pkgs.git-worktree-custom == A custom version of this package
  git-worktree = final: _: {
    git-worktree-custom = final.vimUtils.buildVimPlugin {
      name = "git-worktree";
      dependencies = [ final.vimPlugins.plenary-nvim ];
      src = final.fetchFromGitHub {
        owner = "polarmutex";
        repo = "git-worktree.nvim";
        rev = "bac72c240b6bf1662296c31546c6dad89b4b7a3c";
        sha256 = "sha256-Uvcihnc/+v4svCrAO2ds0XvNmqO801ILWu8sbh/znf4=";
      };
    };
  };

}

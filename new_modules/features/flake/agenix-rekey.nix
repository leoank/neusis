{ self, inputs, ... }:
{
  # Inputs related to secrets
  flake-file.inputs = {
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      #inputs.darwin.follows = "darwin";
    };
    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Import the agenix flake module
  imports = [
    inputs.agenix-rekey.flakeModule
  ];

  # Plumbing agenix and adding devSell for it
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      # Tell agenix-rekey which hosts to consider
      agenix-rekey.nixosConfigurations = self.nixosConfigurations;
      agenix-rekey.darwinConfigurations = self.darwinConfigurations;

      # Add agenix-rekey to your devshell, so you can use the `agenix rekey` command
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = [
          config.agenix-rekey.package
        ];

        # Automatically adds rekeyed secrets to git without
        # requiring `agenix rekey -a`.
        env.AGENIX_REKEY_ADD_TO_GIT = true;
      };
    };
}

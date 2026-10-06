{ pkgs, ... }:
{
  # Ollama service for local LLM inference
  services.ollama = {
    enable = true;
    package = pkgs.ollama;
    acceleration = "cuda";
    environmentVariables = {
      CUDA_VISIBLE_DEVICES = "0";
      LD_LIBRARY_PATH = "${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudatoolkit}/lib64";
    };
  };

  # Optional: Open firewall port if you want to access ollama from other machines
  # networking.firewall.allowedTCPPorts = [ 11434 ];
}
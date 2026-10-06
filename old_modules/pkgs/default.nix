{
  pkgs ? import <nixpkgs> { },
  inputs,
  outputs,
}:
rec {
  specstory = pkgs.callPackage ./specstory { };
  kalamv2 = pkgs.callPackage ./kalamv2 { inherit inputs outputs; };
  xrt = pkgs.callPackage ./xilinx/xrt.nix { };
  # xrt-drivers = pkgs.callPackage ./xilinx/xrt-drivers.nix {
  #   inherit xrt;
  #   kernel = pkgs.linux;
  # };
  # xilinx-env = pkgs.callPackage ./xilinx/fhs-env.nix { };
  # xilinx-firmware = pkgs.callPackage ./xilinx/firmware-u250.nix { };
  # xntools-core = pkgs.callPackage ./xilinx/xntools-core.nix { };
  # firmware-sn1000 = pkgs.callPackage ./xilinx/firmware-sn1000.nix { };
  # xilinx-cable-drivers = pkgs.callPackage ./xilinx/cable-drivers { };
  # intel-cable-drivers = pkgs.callPackage ./intel-fpgas/cable-drivers { };
  # intel-opencl-drivers = pkgs.callPackage ./intel-fpgas/opencl-drivers { };
  kexec_tailscale = pkgs.callPackage ./kexec_tailscale.nix {
    inherit
      pkgs
      inputs
      outputs
      ;
  };
}

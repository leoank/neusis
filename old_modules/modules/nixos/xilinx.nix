# Adapted from https://github.com/TUM-DSE/doctor-cluster-config
{
  pkgs,
  config,
  lib,
  outputs,
  ...
}:
let
  xrt-drivers = outputs.packages.xrt-drivers;
in
{
  options = {
    hardware.xilinx.xrt-drivers.enable = lib.mkEnableOption "Propritary kernel drivers for flashing firmware";
  };

  config = {
    environment.systemPackages = [
      (outputs.packages.xilinx-env.override {
        xilinxName = "xilinx-shell";
        runScript = "bash";
      })
      (outputs.packages.xilinx-env.override {
        xilinxName = "vitis";
        runScript = "vitis";
      })
      outputs.packages.xntools-core

    ];

    services.udev.packages = [ outputs.packages.xilinx-cable-drivers ];

    # 6.0+ kernel
    boot.extraModulePackages = lib.optional (config.hardware.xilinx.xrt-drivers.enable) xrt-drivers;

    # hardware.graphics.extraPackages = [ packages.xrt ];
  };
}

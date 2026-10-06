{pkgs, ...}: {
  home.packages = with pkgs; [
    nvitop
  ];
}

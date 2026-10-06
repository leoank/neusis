{ ... }:
{
  flake.neusis.features.darwin.theme =
    { pkgs, ... }:
    {
      fonts.packages = [ pkgs.nerd-fonts.iosevka ];
    };
}

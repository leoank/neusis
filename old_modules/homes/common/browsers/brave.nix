{ pkgs, ... }:
{
  programs.chromium = {
    enable = true;
    package = pkgs.brave;
    extensions = [
      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # ublock origin
      { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # dark reader
      { id = "faeadnfmdfamenfhaipofoffijhlnkif"; } # Into the black hole theme
      { id = "cdglnehniifkbagbbombnjghhcihifij"; } # kagi search
    ];
    commandLineArgs = [
      "--disable-features=WebRtcAllowInputVolumeAdjustment"
    ];
    # defaultSearchProviderEnabled = true;
    # defaultSearchProviderSearchURL = "https://kagi.com/search?q=%s";
    # defaultSearchProviderSuggestURL = "https://kagi.com/api/autosuggest?q=%s";
  };
  #environment.etc."/brave/policies/managed/GroupPolicy.json".source = ./brave_policy.json;
}

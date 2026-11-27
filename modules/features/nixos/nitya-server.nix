# Neusis feature: nitya's server (nitya ADR-0016), wired for ank's fleet (NixOS).
#
# The service comes from the nitya flake (`nixosModules.server`; the input is declared in
# features/nixos/nitya-token-probe.nix). It joins anklab's leoank tailnet as `nitya`
# (port 7300 there, nothing on the host) and keeps its state in /var/lib/nitya. The
# leoank auth key and nitya's sync-delegate key reach it as systemd credentials from
# agenix. A machine imports `inputs.nitya.nixosModules.server` and this, and defines the
# two `age.secrets.nitya*` secrets below (machines/ghost001.nix does). Admin commands:
# `nitya-admin enroll-code --account ank`, `nitya-admin devices`, `nitya-admin revoke N`.
{ ... }:
{
  flake.neusis.features.nixos.nitya-server =
    { config, ... }:
    {
      services.nitya-server = {
        enable = true;
        authKeyFile = config.age.secrets.nityaServerTsAuthKey.path;
        delegateKeyFile = config.age.secrets.nityaDelegateKey.path;
      };
    };
}

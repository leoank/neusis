# T1/T2: every machine and home configuration becomes a `checks` entry on
# the system it is built for, so `nix flake check --no-build` evaluates
# them all (today's drvPath ladder) and `nix flake check` / `nix build
# .#checks.<system>.<name>` really builds them.
#
#   checks.<system>.darwin-<host>   = darwinConfigurations.<host>.system
#   checks.<system>.nixos-<host>    = nixosConfigurations.<host>.config.system.build.toplevel
#   checks.<system>.home-<user>@<host> = homeConfigurations."<user>@<host>".activationPackage
{ self, lib, ... }:
{
  perSystem =
    { system, ... }:
    let
      forThisSystem = cfgs: lib.filterAttrs (_: c: c.pkgs.stdenv.hostPlatform.system == system) cfgs;
      named = prefix: f: cfgs: lib.mapAttrs' (n: c: lib.nameValuePair "${prefix}${n}" (f c)) (forThisSystem cfgs);
    in
    {
      checks =
        named "darwin-" (c: c.system) self.darwinConfigurations
        // named "nixos-" (c: c.config.system.build.toplevel) self.nixosConfigurations
        // named "home-" (c: c.activationPackage) self.homeConfigurations;
    };
}

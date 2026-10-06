# T1/T2: every machine and home configuration becomes a `checks` entry on
# the system it is built for, so `nix flake check --no-build` evaluates
# them all (today's drvPath ladder) and `nix flake check` / `nix build
# .#checks.<system>.<name>` really builds them.
#
#   checks.<system>.darwin-<host>      = darwinConfigurations.<host>.system
#   checks.<system>.nixos-<host>       = nixosConfigurations.<host>.config.system.build.toplevel
#   checks.<system>.home-<user>@<host> = homeConfigurations."<user>@<host>".activationPackage
#
# The target system comes from the machine registry, not from the
# configuration's `pkgs`: instantiating a host's `pkgs` applies its
# overlays (stylix needs import-from-derivation), which would make even
# `nix flake show` — which forbids IFD — fail while listing `checks`.
{ self, lib, ... }:
{
  perSystem =
    { system, ... }:
    let
      machines = lib.concatMap (r: r.nixos ++ r.darwin) (lib.attrValues self.neusis.registry.machines);
      systemOf =
        host:
        (lib.findFirst (m: m.hostname == host) (throw "checks: no registered machine named ${host}") machines)
        .system;
      hostOf = name: lib.last (lib.splitString "@" name);

      forThisSystem = sysOf: lib.filterAttrs (n: _: sysOf n == system);
      named =
        prefix: sysOf: f: cfgs:
        lib.mapAttrs' (n: c: lib.nameValuePair "${prefix}${n}" (f c)) (forThisSystem sysOf cfgs);
    in
    {
      checks =
        named "darwin-" systemOf (c: c.system) self.darwinConfigurations
        // named "nixos-" systemOf (c: c.config.system.build.toplevel) self.nixosConfigurations
        // named "home-" (n: systemOf (hostOf n)) (c: c.activationPackage) self.homeConfigurations;
    };
}

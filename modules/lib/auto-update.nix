# Auto-update helpers: `flake.neusis.lib.autoUpdate`
# (docs/auto-update-spec.md). Pure functions over a lab's
# `registry.deployGroups.<lab>` and `registry.signers.<lab>`.
{ lib, ... }:
{
  flake.neusis.lib.autoUpdate = rec {
    # Name of the group whose `machines` include `hostname`, or null.
    # Assumes `checkGroups groups == [ ]` (a host in one group at most).
    groupOf =
      groups: hostname:
      let
        names = lib.attrNames (
          lib.filterAttrs (_: g: lib.any (m: m.hostname == hostname) g.machines) groups
        );
      in
      if names == [ ] then null else lib.head names;

    # Problems with a lab's groups, as messages; `[ ]` when valid. Group
    # names become ref components (`deploy/<name>`), a host follows one
    # branch, and `after` must form chains, not loops.
    checkGroups =
      groups:
      let
        names = lib.attrNames groups;
        after = n: groups.${n}.after;

        badNames = lib.filter (n: builtins.match "[a-z0-9][a-z0-9-]*" n == null) names;

        memberships = lib.concatMap (
          n:
          map (m: {
            host = m.hostname;
            group = n;
          }) groups.${n}.machines
        ) names;
        repeated = lib.filterAttrs (_: es: lib.length es > 1) (lib.groupBy (e: e.host) memberships);

        unknownAfter = lib.filter (n: after n != null && !(groups ? ${after n})) names;

        # Walk `after` from `n`; reaching a group already seen is a loop.
        loops =
          n: seen:
          let
            a = after n;
          in
          if a == null || !(groups ? ${a}) then
            false
          else if lib.elem a seen then
            true
          else
            loops a (seen ++ [ a ]);
        cyclic = lib.filter (n: loops n [ n ]) names;

        soakWithoutAfter = lib.filter (n: after n == null && groups.${n}.soakHours > 0) names;
      in
      map (n: "deploy group `${n}`: name must match [a-z0-9][a-z0-9-]*") badNames
      ++ lib.mapAttrsToList (
        h: es:
        "machine `${h}` is in more than one deploy group: ${lib.concatMapStringsSep ", " (e: e.group) es}"
      ) repeated
      ++ map (n: "deploy group `${n}`: `after` names unknown group `${after n}`") unknownAfter
      ++ map (n: "deploy group `${n}`: `after` chain loops back to itself") cyclic
      ++ map (n: "deploy group `${n}`: `soakHours` needs `after`") soakWithoutAfter;

    # CI build matrix for a lab's deploy groups (docs/auto-update-spec.md
    # §6.3): one entry per member with the flake checks that must build
    # before its group may move — its system (`nixos-<host>` or
    # `darwin-<host>`) and every home on it (`home-<user>@<host>`).
    # `checks` is the flake's `checks` output; only its names are read.
    ciMatrix =
      { groups, checks }:
      lib.concatMap (
        group:
        map (
          m:
          let
            host = m.hostname;
            kind = if lib.hasSuffix "darwin" m.system then "darwin" else "nixos";
            names = lib.attrNames (checks.${m.system} or { });
          in
          if !(lib.elem "${kind}-${host}" names) then
            throw "ciMatrix: no check `${kind}-${host}` for ${m.system} (is ${host} in the lab's machine registry?)"
          else
            {
              inherit host group;
              inherit (m) system;
              checks = lib.filter (
                n: n == "${kind}-${host}" || (lib.hasPrefix "home-" n && lib.hasSuffix "@${host}" n)
              ) names;
            }
        ) groups.${group}.machines
      ) (lib.attrNames groups);

    # OpenSSH `allowed_signers` text for a signer list, restricted to git
    # signatures (comin accepts only key entries and `namespaces=`).
    allowedSigners = lib.concatMapStrings (s: "${s.principal} namespaces=\"git\" ${s.key}\n");
  };
}

# Future considerations

Items the codebase doesn't do today, but should be evaluated before the
next round of changes.

## Expose `roleSpecs` via `neusis-options.nix`

Status: deferred — fine as-is for the current set of four roles
(`admin`, `regular`, `guest`, `locked`).

### What's there today

`new_modules/lib/neusisOS.nix` carries a private `roleSpecs` attrset:

```nix
roleSpecs = {
  admin = {
    extraGroups = [ "networkmanager" "wheel" "libvirtd" … ];
  };
  regular   = { extraGroups = [ "libvirtd" … ]; };
  guest     = { extraGroups = [ "input" "podman" "docker" ]; };
  locked    = { extraGroups = [ "input" ]; locked = true; };
};
```

`mkUser` reads `roleSpecs.${role}` to build the user module. Adding a
new role today means editing the lib file.

### The proposed change

Promote the catalogue to a typed flake option so consumers can extend
it from their own modules without forking the lib.

In `new_modules/lib/neusis-options.nix`:

```nix
roleSpecType = types.submodule {
  options = {
    extraGroups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Linux-only group set this role grants.";
    };
    locked = mkOption {
      type = types.bool;
      default = false;
      description = "If true, the role is a no-login account.";
    };
  };
};

# Inside neusisType.options:
roles = mkOption {
  type = types.lazyAttrsOf roleSpecType;
  default = { };
  description = ''
    Role catalogue consumed by `mkUser`/`mkDynamicUsers`.
    Built-in roles (`admin`, `regular`, `guest`, `locked`) are
    provided by neusis; downstream consumers can add more.
  '';
};
```

A separate file (`new_modules/lib/builtin-roles.nix` or similar)
contributes the four built-in roles via `flake.neusis.roles.<name> =
{ extraGroups = …; };`.

`mkUser` then reads `config.flake.neusis.roles.${role}` (passed through
the lib closure) instead of the hard-coded `roleSpecs`.

### Why we haven't done it yet

- Four roles is small enough that the indirection costs more than it
  saves.
- No consumer has asked for a custom role.
- It introduces a closure-over-config dependency in the lib that needs
  care to avoid infinite recursion at flake-eval time (the lib lives at
  `flake.neusis.lib.neusisOS` and reading `config.flake.neusis.roles`
  from inside it requires lazy threading via `self`).

### When to revisit

- A second downstream wants different groups for one of the standard
  roles, or wants a fifth role (`deploy`, `ci`, …).
- The role catalogue grows past ~6 entries.
- A consumer needs to override `extraGroups` per machine rather than
  globally — that's a separate but related design discussion.

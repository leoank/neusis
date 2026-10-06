# Using modules and features

Everything below assumes your repo has `neusis` as a flake input (the
scaffold does this). Module and feature names link to their reference
pages.

## Home-manager modules

Import a home module inside a user's bundle, then set its `enable` option:

```nix
{ self, inputs, ... }:
{
  flake.neusis.users.alice.hmBundles.terminal = {
    imports = [
      inputs.neusis.homeModules.supercharged-shell
      inputs.neusis.homeModules.terminal-velocity
    ];

    neusis.supercharged-shell.enable = true;
    neusis.terminal-velocity.tools = {
      tmux.enable = true;
      zellij.enable = true;
    };
  };

  flake.neusis.users.alice.neusisOS.machineToBundlesMap.laptop = [
    self.neusis.users.alice.hmBundles.terminal
  ];
}
```

*Umbrella* modules (`supercharged-git`, `supercharged-shell`,
`terminal-velocity`) import all of their tool sub-modules for you. Each tool
then has its own `tools.<name>.enable` switch, off by default. You can also
import a single sub-module, such as `homeModules.supercharged-git-delta`, on
its own.

All modules: [Home Manager modules](../reference/home-modules/index.md).

## System modules

System modules go in a machine's `module`. Use `darwinModules` on macOS
and `nixosModules` on NixOS. The modules are the same under both names.

```nix
{ inputs, ... }:
{
  flake.neusis.machines.laptop.module = {
    imports = [
      inputs.neusis.darwinModules.tailscale
      inputs.neusis.darwinModules.kanata
    ];
    neusis.services.tailscale.enable = true;
  };
}
```

All modules: [System modules](../reference/system-modules/index.md).

## Features

A feature has no options, so importing it is all you do:

```nix
flake.neusis.machines.laptop.module = {
  imports = [
    inputs.neusis.neusis.features.darwin.system-defaults
    inputs.neusis.neusis.features.agnostic.nix-settings
  ];
};
```

The first `neusis` is the flake input and the second is the flake's
`neusis` output. Every feature's source is shown on the
[Features](../reference/features.md) page. If one is close to what you
want but not quite, copy it into your own repo.

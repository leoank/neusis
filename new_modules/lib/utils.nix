{
  lib,
  inputs,
  ...
}:
{
  flake.neusis.lib.utils = {
    helloWorld = name: builtins.trace "Debug message" { hello = name; };
  };
}

# Candidate 1 for neusis: agenix's darwin job is restarted only when it fails. Upstream's
# KeepAlive also has Crashed = false, which launchd reads as "restart when it did not crash".
{ lib, ... }:
{
  launchd.agents.activate-agenix.config.KeepAlive = lib.mkForce { SuccessfulExit = false; };
}

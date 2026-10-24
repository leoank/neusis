# Tests for flake.neusis.features.agnostic.auto-update: a host follows the
# branch of its anklab deploy group, trusts the anklab signers and mails
# failures to the fixed addresses; a host in no group fails an assertion.
{ self, inputs, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;

      onNixos =
        host: extra:
        t.evalNixos {
          modules = [
            inputs.comin.nixosModules.comin
            self.nixosModules.auto-update
            self.neusis.features.agnostic.auto-update
            { networking.hostName = host; }
            extra
          ];
        };

      onDarwin =
        host:
        t.evalDarwin {
          modules = [
            inputs.comin.darwinModules.comin
            self.darwinModules.auto-update
            self.neusis.features.agnostic.auto-update
            { networking.hostName = host; }
          ];
        };

      summary =
        cfg:
        let
          au = cfg.neusis.services.auto-update;
        in
        {
          inherit (au)
            url
            branch
            pollPeriod
            signers
            ;
          inherit (au.notify)
            emailFrom
            emailTo
            environmentFile
            onSuccess
            ;
          failed = t.failedAssertions cfg;
        };

      common = {
        url = "https://github.com/leoank/neusis.git";
        pollPeriod = 60;
        signers = self.neusis.registry.signers.anklab;
        emailFrom = "ghcibot@leoank.me";
        emailTo = [ "leoank98@gmail.com" ];
        environmentFile = null;
        # ntfy is phase 2; success pings have no other channel
        onSuccess = false;
        failed = [ ];
      };
    in
    {
      tests.feature-auto-update = {
        test-ghost001-follows-canary = {
          expr = summary (onNixos "ghost001" { });
          expected = common // {
            branch = "deploy/canary";
          };
        };

        test-rogue-follows-stable = {
          expr = summary (onDarwin "rogue");
          expected = common // {
            branch = "deploy/stable";
          };
        };

        test-a-machine-can-poll-faster = {
          expr = (onNixos "ghost001" { neusis.services.auto-update.pollPeriod = 10; }).services.comin.remotes;
          expected = map (r: r // { poller.period = 10; }) (onNixos "ghost001" { }).services.comin.remotes;
        };

        test-a-host-outside-every-group-fails = {
          expr = t.failedAssertions (onNixos "stranger" { });
          expected = [
            "auto-update: stranger is in no anklab deploy group (modules/registry/deploy-groups/anklab.nix)."
          ];
        };
      };
    };
}

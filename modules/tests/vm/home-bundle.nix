# T3: neusis home-manager modules at runtime. alice gets a bundle of
# supercharged-git / supercharged-shell / terminal-velocity tools through
# the normal machineToBundlesMap path; the test checks the rendered files
# and that the tools run from her profile. Heavy closures (the shell
# umbrella's toolchains, GUI terminals, agent CLIs) are left out — their
# wiring is covered at eval level.
{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      t = self.neusis.lib.tests;
      f = t.fixtures;
      os = self.neusis.lib.neusisOS;

      bundle = {
        imports = [
          self.homeModules.supercharged-git
          self.homeModules.supercharged-shell
          self.homeModules.terminal-velocity
        ];
        # zsh integrations only materialise when the shell is managed
        programs.zsh.enable = true;
        neusis.supercharged-git = {
          enable = true;
          userName = "Alice Fixture";
          userEmail = "alice@example.com";
          tools = {
            delta.enable = true;
            lazygit.enable = true;
            mergiraf.enable = true;
          };
        };
        neusis.supercharged-shell.tools = {
          direnv.enable = true;
          fzf.enable = true;
          zoxide.enable = true;
          yazi.enable = true;
        };
        neusis.terminal-velocity.tools = {
          tmux.enable = true;
          sesh.enable = true;
        };
      };

      alice = f.alice // {
        machineToBundlesMap.fixture = [ bundle ];
      };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-home-bundle = t.mkVmTest pkgs {
          name = "vm-home-bundle";

          nodes.fixture.imports = os.mkNeusisOSModules {
            machineName = "fixture";
            userModule = f.vmNode;
            userRegistries = [ (f.lab // { admins = [ alice ]; }) ];
            initialHashedPassword = f.machines.vm.initialHashedPassword;
          };

          testScript = ''
            fixture.wait_for_unit("multi-user.target")
            fixture.wait_for_unit("home-manager-alice.service")

            def alice(cmd):
                return fixture.succeed(f"su - alice -c {cmd!r}")

            bin = "/home/alice/.nix-profile/bin"

            with subtest("git identity, SSH signing and the integrations are rendered"):
                assert alice(f"{bin}/git config --get user.name").strip() == "Alice Fixture"
                assert alice(f"{bin}/git config --get commit.gpgsign").strip() == "true"
                assert alice(f"{bin}/git config --get gpg.format").strip() == "ssh"
                assert alice(f"{bin}/git config --get merge.mergiraf.name").strip() == "mergiraf"
                # home-manager wires delta via interactive.diffFilter + per-command pagers
                assert "delta" in alice(f"{bin}/git config --get interactive.diffFilter")
                assert "delta" in alice(f"{bin}/git config --get pager.diff")

            with subtest("shell integrations land in alice's zshrc"):
                zshrc = alice("cat ~/.zshrc")
                for needle in ["direnv hook zsh", "zoxide init", "fzf", "yy"]:
                    assert needle in zshrc, f"{needle!r} missing from .zshrc"

            with subtest("tmux config carries the neusis bindings"):
                alice("grep -q 'sesh last' ~/.config/tmux/tmux.conf")

            with subtest("the tools run from alice's profile"):
                for tool in ["gclb --help", "delta --version", "lazygit --version", "mergiraf --version",
                             "direnv --version", "fzf --version", "zoxide --version", "yazi --version",
                             "tmux -V", "sesh --version"]:
                    alice(f"{bin}/{tool}")
          '';
        };
      };
    };
}

# T3: distributed builds end to end. `server` runs the agnostic
# build-server module (dedicated nix-trusted user, our test build key
# authorised, a pinned host key); `client` runs build-client pointing at
# it. The client must reach the server's store over ssh-ng and really
# offload a build.
{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      t = self.neusis.lib.tests;
      vm = ../_fixtures/vm;
      system = pkgs.stdenv.hostPlatform.system;
      serverHostPubkey = lib.removeSuffix "\n" (builtins.readFile (vm + "/server_host_key.pub"));
      nix = "nix --extra-experimental-features nix-command";
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-build-cluster = t.mkVmTest pkgs {
          name = "vm-build-cluster";

          nodes.server = {
            imports = [ self.nixosModules.build-server ];
            neusis.services.build-server = {
              enable = true;
              authorizedKeyFiles = [ (vm + "/build_key.pub") ];
            };
            services.openssh.enable = true;
            # present the TEST-ONLY host key the client pins
            services.openssh.hostKeys = [
              {
                path = "/etc/ssh/ssh_host_ed25519_key";
                type = "ed25519";
              }
            ];
            environment.etc."ssh/ssh_host_ed25519_key" = {
              source = vm + "/server_host_key";
              mode = "0600";
            };
          };

          nodes.client = {
            imports = [ self.nixosModules.build-client ];
            neusis.services.build-client = {
              enable = true;
              builders = [
                {
                  hostName = "server";
                  sshUser = "nixremote";
                  systems = [ system ];
                  maxJobs = 2;
                  speedFactor = 1;
                  supportedFeatures = [ ];
                  mandatoryFeatures = [ ];
                  hostPubkey = serverHostPubkey;
                }
              ];
            };
            # the module's default sshKey path; root-only like the real key
            environment.etc."nix/remote-build-key" = {
              source = vm + "/build_key";
              mode = "0600";
            };
          };

          testScript = ''
            start_all()
            server.wait_for_unit("sshd.service")
            client.wait_for_unit("multi-user.target")

            with subtest("server: dedicated, trusted build user"):
                server.succeed("id nixremote")
                assert "nixremote" in server.succeed("grep trusted-users /etc/nix/nix.conf")
                server.succeed("grep -q 'neusis test build key' /etc/ssh/authorized_keys.d/nixremote")

            with subtest("client: builder offered, host key pinned"):
                assert "ssh-ng://nixremote@server" in client.succeed("cat /etc/nix/machines")
                client.succeed("grep -q '^server ' /etc/ssh/ssh_known_hosts")

            with subtest("client reaches the server's store over ssh-ng"):
                # `nix store info` does not read the machines file, so name the
                # key explicitly; builds below get it from nix.buildMachines.
                client.wait_until_succeeds(
                    "${nix} store info --store 'ssh-ng://nixremote@server?ssh-key=/etc/nix/remote-build-key'",
                    timeout=120,
                )

            with subtest("a build is offloaded to the server"):
                # --max-jobs 0 forbids local builds: success means the server
                # built it (the sandbox hostname is always `localhost`, so the
                # output cannot name the host).
                out = client.succeed(
                    "${nix} build --max-jobs 0 --no-link --print-out-paths --expr "
                    "'derivation { name = \"offloaded\"; system = \"${system}\"; builder = \"/bin/sh\"; "
                    "args = [ \"-c\" \"echo offloaded > $out\" ]; }'"
                ).strip()
                assert client.succeed(f"cat {out}").strip() == "offloaded", "unexpected output of the offloaded build"
                client.fail("${nix} build --max-jobs 0 --builders \"\" --no-link --expr "
                            "'derivation { name = \"local-only\"; system = \"${system}\"; builder = \"/bin/sh\"; args = [ \"-c\" \"echo x > $out\" ]; }'")
          '';
        };
      };
    };
}

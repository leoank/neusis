# T3: auto-updates end to end. One node runs comin through
# nixosModules.auto-update against a local bare repo on `deploy/canary`,
# trusting the TEST-ONLY signing key. Local stub servers stand in for ntfy
# and Postmark. The repo flake (_auto-update-repo/) has a fake toplevel
# whose switch writes a marker, so each deploy is visible and cheap:
#
#   signed commit     → switched, logged `done`, ntfy ping, no email
#   unsigned commit   → refused, nothing changes
#   eval failure      → nothing changes, no hook
#   failing switch    → logged `failed`, ntfy + email
#   signed commit     → switched again
{ self, inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      t = self.neusis.lib.tests;
      vm = ../_fixtures/vm;
      system = pkgs.stdenv.hostPlatform.system;

      repoFlake = pkgs.replaceVars ./_auto-update-repo/flake.nix {
        inherit system;
        busybox = pkgs.pkgsStatic.busybox;
      };

      # Records every POST (path, headers, body) as a JSON line.
      stub = pkgs.writers.writePython3 "notify-stub" { } ''
        import http.server
        import json


        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(length).decode()
                with open("/var/log/notify-stub.jsonl", "a") as log:
                    log.write(json.dumps({
                        "path": self.path,
                        "headers": dict(self.headers),
                        "body": body,
                    }) + "\n")
                self.send_response(202)
                self.end_headers()


        http.server.HTTPServer(("127.0.0.1", 8090), Handler).serve_forever()
      '';
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-auto-update = t.mkVmTest pkgs {
          name = "vm-auto-update";

          nodes.machine = {
            imports = [
              inputs.comin.nixosModules.comin
              self.nixosModules.auto-update
            ];

            neusis.services.auto-update = {
              enable = true;
              url = "/var/lib/neusis-repo";
              branch = "deploy/canary";
              pollPeriod = 2;
              signers = [
                {
                  principal = "ci@example.com";
                  key = lib.concatStringsSep " " (
                    lib.take 2 (lib.splitString " " (lib.fileContents (vm + "/signing_key.pub")))
                  );
                }
              ];
              notify = {
                environmentFile = "/etc/neusis-notify.env";
                ntfyUrl = "http://127.0.0.1:8090";
                emailFrom = "bot@example.com";
                emailTo = [ "alice@example.com" ];
              };
            };

            environment.etc."neusis-notify.env".text = ''
              NTFY_TOPIC=deploys
              POSTMARK_API_KEY=fake-key
              POSTMARK_URL=http://127.0.0.1:8090/email
            '';
            environment.etc."neusis-test/signing_key" = {
              source = vm + "/signing_key";
              mode = "0600";
            };
            # git signs with `ssh-keygen -Y sign`
            environment.systemPackages = [
              pkgs.git
              pkgs.openssh
            ];

            # No network, so no registry lookups.
            nix.settings = {
              flake-registry = "";
              experimental-features = [
                "nix-command"
                "flakes"
              ];
            };

            systemd.services.notify-stub = {
              wantedBy = [ "multi-user.target" ];
              serviceConfig.ExecStart = "${stub}";
            };
          };

          testScript = ''
            import json

            repo = "/var/lib/neusis-repo"
            work = "/root/work"


            def git(args):
                return machine.succeed(f"cd {work} && git {args}").strip()


            def push(state, signed=True):
                machine.succeed(f"cat > {work}/state.nix <<'EOF'\n{state}\nEOF")
                git("add -A")
                git(f"commit -q {'-S' if signed else '--no-gpg-sign'} -m 'state: {state}'")
                git(f"push -q {repo} HEAD:refs/heads/deploy/canary")
                return git("rev-parse HEAD")


            def jsonl(path):
                out = machine.succeed(f"cat {path} 2>/dev/null || true")
                return [json.loads(line) for line in out.splitlines() if line.strip()]


            def deploys():
                return jsonl("/var/log/neusis/auto-update.jsonl")


            def notifications():
                return jsonl("/var/log/notify-stub.jsonl")


            def marker():
                return machine.succeed("cat /run/neusis-marker 2>/dev/null || true").strip()


            def wait_for_deploy(sha, count):
                machine.wait_until_succeeds(
                    f"[ $(grep -c . /var/log/neusis/auto-update.jsonl) -ge {count} ]", timeout=240
                )
                last = deploys()[-1]
                assert last["sha"] == sha, f"expected a deploy of {sha}, got {last}"
                return last


            def wait_until_seen(sha):
                machine.wait_until_succeeds(f"journalctl -u comin | grep -q {sha}", timeout=240)


            start_all()
            machine.wait_for_unit("notify-stub.service")
            machine.wait_for_unit("comin.service")

            machine.succeed(
                f"git init -q --bare {repo}",
                f"mkdir -p {work}",
                f"cd {work} && git init -q -b main",
                f"cd {work} && git config user.email ci@example.com",
                f"cd {work} && git config user.name CI",
                f"cd {work} && git config gpg.format ssh",
                f"cd {work} && git config user.signingkey /etc/neusis-test/signing_key",
                f"cp ${repoFlake} {work}/flake.nix",
                f"echo '{{ marker = \"v0\"; switch = true; }}' > {work}/state.nix",
                f"cd {work} && git add -A && nix flake lock",
            )

            with subtest("a signed commit is deployed, logged and announced"):
                v1 = push('{ marker = "v1"; switch = true; }')
                d = wait_for_deploy(v1, 1)
                assert d["status"] == "done", d
                assert d["ref"] == "origin/deploy/canary", d
                assert d["brew"] is None, d
                assert marker() == "v1"
                machine.wait_until_succeeds("grep -q /deploys /var/log/notify-stub.jsonl", timeout=60)
                ping = notifications()[-1]
                assert ping["headers"]["Priority"] == "min", ping
                assert not any(n["path"] == "/email" for n in notifications()), "a success must not email"

            with subtest("an unsigned head is refused"):
                v2 = push('{ marker = "v2"; switch = true; }', signed=False)
                machine.wait_until_succeeds(
                    f"journalctl -u comin | grep -q 'commit {v2} is not evaluated because it is not signed'",
                    timeout=240,
                )
                machine.sleep(6)
                assert marker() == "v1"
                assert len(deploys()) == 1

            with subtest("a commit that fails to evaluate changes nothing"):
                broken = push('throw "broken on purpose"')
                wait_until_seen(broken)
                machine.sleep(10)
                assert marker() == "v1"
                assert len(deploys()) == 1

            with subtest("a failing switch is logged and alerted by ntfy and email"):
                v4 = push('{ marker = "v4"; switch = false; }')
                d = wait_for_deploy(v4, 2)
                assert d["status"] == "failed", d
                assert marker() == "v1"
                machine.wait_until_succeeds("grep -q '\"/email\"' /var/log/notify-stub.jsonl", timeout=60)
                sent = notifications()
                mail = [n for n in sent if n["path"] == "/email"][-1]
                assert mail["headers"]["X-Postmark-Server-Token"] == "fake-key", mail
                body = json.loads(mail["body"])
                assert body["From"] == "neusis <bot@example.com>", body
                assert body["To"] == "alice@example.com", body
                assert body["MessageStream"] == "outbound", body
                assert "failed" in body["Subject"], body
                assert any(n["path"] == "/deploys" and n["headers"]["Priority"] == "high" for n in sent), sent

            with subtest("the next signed commit deploys again"):
                v5 = push('{ marker = "v5"; switch = true; }')
                d = wait_for_deploy(v5, 3)
                assert d["status"] == "done", d
                assert marker() == "v5"
          '';
        };
      };
    };
}

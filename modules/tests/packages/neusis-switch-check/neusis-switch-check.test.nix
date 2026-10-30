# T2: neusis-switch-check (modules/packages/neusis-switch-check/) against a
# stub of GitHub's compare API on 127.0.0.1, in the build sandbox (Linux
# only: the darwin sandbox has no loopback server). The stub answers
# `compare/<branch>...<rev>` from a table; branches it doesn't know are 404.
#
#   aaa identical on deploy/canary          → allowed
#   bbb behind deploy/canary                → allowed
#   ccc ahead, no testing branch            → refused
#   ddd ahead on canary, in testing-rogue   → allowed
#   eee-dirty / empty revision              → allowed, warns
#   GitHub unreachable, or HTTP 500         → allowed, warns
#   ccc with force-switch                   → allowed once, flag removed
{ ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        neusis-switch-check-cases =
          pkgs.runCommand "neusis-switch-check-cases"
            {
              nativeBuildInputs = [
                config.packages.neusis-switch-check
                pkgs.python3
              ];
              stub = pkgs.writeText "compare-stub.py" ''
                import http.server
                import json
                import sys

                TABLE = {
                    "deploy/canary...aaa": "identical",
                    "deploy/canary...bbb": "behind",
                    "deploy/canary...ccc": "ahead",
                    "deploy/canary...ddd": "ahead",
                    "testing-rogue...ddd": "behind",
                }


                class Handler(http.server.BaseHTTPRequestHandler):
                    def do_GET(self):
                        key = self.path.split("/compare/", 1)[-1]
                        if key.startswith("broken/"):
                            self.send_response(500)
                            self.end_headers()
                            return
                        branch = key.split("...")[0]
                        if key in TABLE:
                            self.send_response(200)
                            self.end_headers()
                            self.wfile.write(json.dumps({"status": TABLE[key]}).encode())
                        elif any(k.startswith(branch + "...") for k in TABLE):
                            self.send_response(200)
                            self.end_headers()
                            self.wfile.write(json.dumps({"status": "diverged"}).encode())
                        else:
                            self.send_response(404)
                            self.end_headers()

                    def log_message(self, *args):
                        pass


                http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
              '';
            }
            ''
              set -euo pipefail
              python3 $stub 18321 &
              for _ in $(seq 50); do
                (exec 3<>/dev/tcp/127.0.0.1/18321) 2>/dev/null && break
                sleep 0.1
              done
              export GITHUB_API=http://127.0.0.1:18321
              export NEUSIS_STATE_DIR=$TMPDIR/state
              mkdir -p $NEUSIS_STATE_DIR

              check() { neusis-switch-check "$1" leoank/neusis deploy/canary testing-rogue; }
              allowed() { # name rev
                if check "$2" 2>$TMPDIR/err; then echo "ok: $1"; else
                  echo "FAIL: $1 was refused" >&2; cat $TMPDIR/err >&2; exit 1; fi
              }
              refused() { # name rev
                if check "$2" 2>$TMPDIR/err; then
                  echo "FAIL: $1 was allowed" >&2; exit 1; fi
                grep -q "refusing to activate $2" $TMPDIR/err
                echo "ok: $1"
              }
              warned() { # name
                grep -q "warning" $TMPDIR/err || { echo "FAIL: $1 did not warn" >&2; exit 1; }
                echo "ok: $1 warns"
              }

              allowed identical aaa
              allowed behind bbb
              refused ahead ccc
              allowed testing ddd
              allowed dirty eee-dirty; warned dirty
              allowed unknown ""; warned unknown
              GITHUB_API=http://127.0.0.1:1 allowed unreachable ccc; warned unreachable
              neusis-switch-check ccc leoank/neusis broken/x 2>$TMPDIR/err && echo "ok: http 500"; warned "http 500"
              touch $NEUSIS_STATE_DIR/force-switch
              allowed forced ccc; warned forced
              [ ! -e $NEUSIS_STATE_DIR/force-switch ] && echo "ok: force-switch consumed"
              refused "ahead again" ccc

              touch $out
            '';
      };
    };
}

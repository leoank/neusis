# T2: neusis-promote (modules/packages/neusis-promote/) against a local bare
# "origin", in the build sandbox. Groups: canary (from main), fast (after
# canary, no soak) and stable (after canary, 24 h). Time is driven through
# NOW; the trusted key is the TEST-ONLY fixture key, and a second key made
# here plays an untrusted signer. Each commit lists the hosts it enrolls
# in a file `enrolled`, which a stub ENROLLED_CMD reads instead of
# evaluating the flake; canary's member is rogue.
#
#   c1 signed, gated          → canary and fast promoted, stable waiting
#   c2 signed, gates failed   → canary held
#   c3 unsigned               → canary held
#   c4 signed by another key  → canary held
#   c5 signed, gated          → canary and fast promoted (fast-forward over c2–c4)
#   no candidate (hourly run) → canary untouched
#   +24.5 h                   → stable promoted to c1 (c5 has not soaked yet)
#   +25 h                     → stable promoted to c5
#   c6 with canary in DEPLOY_HOLD → paused
#   c7 drops rogue's enrollment → held, would unenroll rogue
#   c8 enrolls rogue again    → canary promoted
#   d branched off c1         → held, not a fast-forward
{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    {
      checks.neusis-promote-cases =
        pkgs.runCommand "neusis-promote-cases"
          {
            nativeBuildInputs = [
              config.packages.neusis-promote
              pkgs.git
              pkgs.jq
              pkgs.openssh
            ];
            fixtures = ../../_fixtures/vm;
          }
          ''
            set -euo pipefail
            export HOME=$TMPDIR/home
            mkdir -p $HOME
            git config --global init.defaultBranch main
            git config --global user.name ci
            git config --global user.email ci@example.com
            git config --global gpg.format ssh

            install -m 600 $fixtures/signing_key $TMPDIR/trusted
            ssh-keygen -q -t ed25519 -N "" -f $TMPDIR/untrusted
            echo "ci@example.com namespaces=\"git\" $(cut -d' ' -f1,2 $fixtures/signing_key.pub)" > $TMPDIR/allowed
            printf '#!/bin/sh\ncat %s\n' $TMPDIR/allowed > $TMPDIR/signers
            chmod +x $TMPDIR/signers
            export SIGNERS_CMD=$TMPDIR/signers
            cat > $TMPDIR/enrolled <<'EOF'
            #!/bin/sh
            if git show "$1:enrolled" 2>/dev/null | grep -qx "$3"; then echo true; else echo false; fi
            EOF
            chmod +x $TMPDIR/enrolled
            export ENROLLED_CMD=$TMPDIR/enrolled

            cat > $TMPDIR/groups.json <<'EOF'
            {
              "canary": { "branch": "deploy/canary", "after": null, "soakHours": 0,
                          "members": [ { "host": "rogue", "kind": "darwin" } ] },
              "fast": { "branch": "deploy/fast", "after": "canary", "soakHours": 0 },
              "stable": { "branch": "deploy/stable", "after": "canary", "soakHours": 24 }
            }
            EOF

            git init -q --bare $TMPDIR/origin.git
            git clone -q $TMPDIR/origin.git $TMPDIR/work
            cd $TMPDIR/work

            T0=1800000000
            hosts=rogue
            commit() { # name key|-
              echo "$1" > state
              echo "$hosts" > enrolled
              git add state enrolled
              if [ "$2" = - ]; then
                git commit -q --no-gpg-sign -m "$1"
              else
                git -c user.signingkey="$2" commit -q -S -m "$1"
              fi
              git push -q origin HEAD:main
              git rev-parse HEAD
            }
            promote() { # now [args…] → report in $TMPDIR/r.json
              local now=$1
              shift
              NOW=$now neusis-promote --groups $TMPDIR/groups.json --report $TMPDIR/r.json --push "$@"
            }
            action() { jq -r --arg g "$1" '.[] | select(.group == $g) | .action' $TMPDIR/r.json; }
            reason() { jq -r --arg g "$1" '.[] | select(.group == $g) | .reason' $TMPDIR/r.json; }
            at() { git ls-remote $TMPDIR/origin.git "refs/heads/deploy/$1" | cut -f1; }
            expect() { # what got want
              if [ "$2" != "$3" ]; then
                echo "FAIL: $1: got '$2', want '$3'" >&2
                cat $TMPDIR/r.json >&2
                exit 1
              fi
              echo "ok: $1"
            }

            c1=$(commit c1 $TMPDIR/trusted)
            promote $T0 --candidate $c1 --gated true
            expect "c1 canary" "$(action canary)" promoted
            expect "c1 fast" "$(action fast)" promoted
            expect "c1 stable" "$(action stable)" waiting
            expect "c1 canary ref" "$(at canary)" $c1
            expect "c1 fast ref" "$(at fast)" $c1
            expect "c1 stable ref" "$(at stable)" ""

            c2=$(commit c2 $TMPDIR/trusted)
            promote $((T0 + 600)) --candidate $c2 --gated false
            expect "c2 canary" "$(action canary)" held
            expect "c2 reason" "$(reason canary)" "the gates failed on $c2"
            expect "c2 canary ref" "$(at canary)" $c1

            c3=$(commit c3 -)
            promote $((T0 + 1200)) --candidate $c3 --gated true
            expect "c3 canary" "$(action canary)" held
            expect "c3 reason" "$(reason canary)" "$c3 is not signed by an allowed signer"

            c4=$(commit c4 $TMPDIR/untrusted)
            promote $((T0 + 1800)) --candidate $c4 --gated true
            expect "c4 canary" "$(action canary)" held
            expect "c4 canary ref" "$(at canary)" $c1

            c5=$(commit c5 $TMPDIR/trusted)
            promote $((T0 + 3600)) --candidate $c5 --gated true
            expect "c5 canary" "$(action canary)" promoted
            expect "c5 fast" "$(action fast)" promoted
            expect "c5 canary ref" "$(at canary)" $c5
            expect "c5 fast ref" "$(at fast)" $c5

            promote $((T0 + 7200))
            expect "hourly canary untouched" "$(action canary)" ""
            expect "hourly fast" "$(action fast)" unchanged
            expect "hourly stable" "$(action stable)" waiting

            promote $((T0 + 24 * 3600 + 1800))
            expect "+24.5h stable" "$(action stable)" promoted
            expect "+24.5h stable ref" "$(at stable)" $c1

            promote $((T0 + 25 * 3600))
            expect "+25h stable" "$(action stable)" promoted
            expect "+25h stable ref" "$(at stable)" $c5

            c6=$(commit c6 $TMPDIR/trusted)
            DEPLOY_HOLD="other, canary" promote $((T0 + 26 * 3600)) --candidate $c6 --gated true
            expect "hold canary" "$(action canary)" paused
            expect "hold canary ref" "$(at canary)" $c5

            hosts=""
            c7=$(commit c7 $TMPDIR/trusted)
            promote $((T0 + 26 * 3600 + 600)) --candidate $c7 --gated true
            expect "unenroll canary" "$(action canary)" held
            expect "unenroll reason" "$(reason canary)" "$c7 would unenroll rogue (comin off or not on deploy/canary there); take a host out of the group before dropping comin"
            expect "unenroll canary ref" "$(at canary)" $c5

            hosts=rogue
            c8=$(commit c8 $TMPDIR/trusted)
            promote $((T0 + 26 * 3600 + 1200)) --candidate $c8 --gated true
            expect "re-enroll canary" "$(action canary)" promoted
            expect "re-enroll canary ref" "$(at canary)" $c8

            git checkout -q -b side $c1
            d=$(echo d > state && git add state && git -c user.signingkey=$TMPDIR/trusted commit -q -S -m d && git rev-parse HEAD)
            promote $((T0 + 27 * 3600)) --candidate $d --gated true
            expect "side canary" "$(action canary)" held
            expect "side reason" "$(reason canary)" "deploy/canary does not fast-forward from $c8 to $d"

            touch $out
          '';
    };
}

# VM test fixtures — TEST ONLY

Every key in this directory is public by design: it exists so the NixOS VM
tests under `modules/tests/vm/` can exercise agenix secrets and SSH-based
distributed builds without network access or real credentials. Nothing here
protects anything; never reuse these keys.

| File | Purpose |
|---|---|
| `age_key`, `age_key.pub` | age identity the fixture hosts use as `age.identityPaths` |
| `hashedInitialPassword.age` | `mkpasswd -m sha-512 neusis-test`, encrypted to `age_key.pub` — the fixture login password is `neusis-test` |
| `build_key`, `build_key.pub` | SSH key the build-client node uses to reach the build-server node |
| `server_host_key`, `server_host_key.pub` | SSH host key of the build-server node, pinned by the client's `knownHosts` |

Regenerate with `age-keygen`, `mkpasswd`, `ssh-keygen` (see the `vm-*`
tests for how each is wired).

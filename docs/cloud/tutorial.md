# Cloud machines on OCI — operator runbook

How to take a neusis machine from "a file in `modules/machines/`" to a
running NixOS host on Oracle Cloud, and how to operate it afterwards.
Design and rationale: `docs/cloud-terranix-spec.md`; the build-out
trail with every gotcha: `docs/cloud-terranix-progress.md`. Everything
here was run for real against `ghost001` (2026-10-24).

## 0. The pieces

| Piece | Where | What it does |
|---|---|---|
| terranix stacks | `modules/infra/<stack>.nix` → `nix run .#<stack>.{plan,apply,destroy,terraform}` | `oci-images` uploads/imports the base image, `oci-anklab` provisions network + instances |
| reusable terranix modules | `modules/terranixModules/` (`state-encryption`, `oci-provider`, `oci-network`, `oci-image`, `oci-instance`) | the OCI resources, typed by `neusis.oci.*` options |
| base image | `packages.<linux>.oci-base-image` (`modules/images/oci-base.nix`, `lib.cloud.mkOciBaseImage`) | one qcow2 per architecture, no host-specific content |
| guest profile | `features.nixos.oci-guest` | imported by the image *and* every host, so a switch keeps disk layout + bootloader |
| CLI | `neusis cloud bootstrap <host>`, `neusis cloud deploy <host>` | first switch (pushes the pre-generated host key) and day-2 switches |
| state | `infra/<stack>/terraform.tfstate`, encrypted client-side, committed | the only copy; the passphrase is a secret |
| operator secrets | `~/.oci/config`, `~/.oci/neusis_api_key.pem`, `~/.config/neusis/tf.env` (ank's `secrets` home bundle) | OCI API key + `TF_VAR_region`, `TF_VAR_compartment_ocid`, `TF_VAR_state_passphrase` |

Every stack command must run from the repository root (the wrapper
checks) and sources `tf.env` (or `$NEUSIS_TF_ENV`). The wrappers forward
arguments: `nix run .#oci-anklab.plan -- -detailed-exitcode`.

## 1. One-time account setup

Done once per tenancy; details and the exact IAM policy are in
`docs/cloud-terranix-plan.md` ("Operator prerequisites"). In short:

1. Compartment `neusis`, group `neusis-admins` with the policy
   (`manage all-resources in compartment neusis`, plus `inspect
   compartments`, `inspect compute-global-image-capability-schema`,
   `inspect backup-policies` in tenancy).
2. An API key for the operator user → `ociApiKey` (PEM), `ociConfig`
   (`[DEFAULT]` profile), `ociTfEnv` as agenix secrets under
   `modules/secrets/ank/`, delivered by the home bundle.
3. Pay-As-You-Go. Always Free tenancies have a custom-image quota of 0
   (the import fails with `QuotaExceeded custom-image-count`) and reclaim
   A1 instances idle for 7 days; PAYG lifts both while staying inside the
   free A1 allowance (4 OCPUs / 24 GB, 200 GB block storage).

## 2. Define the machine (before anything exists)

1. Generate the host key locally and store it encrypted to the master
   identity: `modules/secrets/bootstrap/<host>/etc/ssh/ssh_host_ed25519_key.age`
   (+ the `.pub` next to it). `hostPubkey` in the machine file is this
   public half, so `agenix rekey` prepares the host's secrets up front.
2. `modules/machines/<host>.nix`: `system`, `hostPubkey`, `userRegistries`,
   `initialHashedPassword`, and a `module` importing
   `features.nixos.oci-guest`, nix settings, agenix + `nixosModules.secrets`,
   distributed builds and a mesh (`cslab_mesh`). Add it to
   `registry/machines/anklab.nix`; optionally to the builders registry.
3. **Classic-agenix secrets need the new host as a recipient.**
   `initialHashedPassword` is an `age.secrets.<n>.file` secret (not
   rekeyed): add the host key to its recipients *before* the first
   switch, or the seeded password never lands and the account stays
   locked (`passwd -S` → `L`; NixOS keeps an existing shadow entry when
   `users.mutableUsers = true`). Re-encrypt without ever writing the
   plaintext to disk:

   ```bash
   age -d -i ~/.ssh/id_ed25519 modules/secrets/common/hashedInitialPassword.age \
     | age -R recipients.txt -o /tmp/x.age && mv -f /tmp/x.age modules/secrets/common/hashedInitialPassword.age
   ```
   (`recipients.txt` = master pubkey + every host pubkey, one per line.)
4. `agenix rekey`, then **`git add` the new `modules/secrets/rekeyed/<host>/`
   files** — a git flake only sees tracked files; an untracked rekeyed
   dir fails eval with "Rekeyed secret … not found".
5. Verify: `nix run .#neusis-test`, `nix eval .#checks.aarch64-linux.nixos-<host>.drvPath`.

## 3. Bake and import the base image (`oci-images`)

Only needed when no image for the architecture exists yet, or you want a
newer one for *future* hosts (existing instances ignore image changes).

- The image build (`make-disk-image`) runs in a VM with virtiofsd and
  cannot run under binfmt emulation. Build it on a native builder for the
  architecture: ghost001 itself once it exists (`nix build
  .#packages.aarch64-linux.oci-base-image` offloads there), or the ad-hoc
  `darwin.linux-builder` VM recipe in `docs/cloud-terranix-plan.md`
  ("Baking the image").
- `nix run .#oci-images.plan`, then `.apply`: uploads the qcow2 to the
  `neusis-images` bucket (object `<name>-<storehash>.qcow2`, ≈70 s for
  2.6 GB) and imports it as a custom image with the Arm/UEFI capability
  schema. The image is looked up by display name later, never by OCID.

## 4. Provision (`oci-anklab`)

1. Declare the network and the instance in `modules/infra/oci-anklab.nix`
   (`neusis.oci.network.<n>`, `neusis.oci.instances.<host>` bound to
   `self.neusis.machines.<host>`; shape must match the machine's
   architecture — an assertion checks).
2. `nix run .#oci-anklab.plan` → read it (look for `-/+ replace` on
   instances) → `nix run .#oci-anklab.apply`. ≈1 min for an A1 instance.
3. IPs: `nix run .#oci-anklab.terraform -- output -json`.
4. Commit `infra/oci-anklab/terraform.tfstate` (encrypted) with the change.

## 5. Bootstrap (first switch)

```bash
nix develop -c neusis cloud bootstrap <host>          # from the repo root
```

Reads the IP from the stack output, waits for SSH, pushes the host key
from `modules/secrets/bootstrap/<host>/` (decrypted with your master
identity), restarts sshd, verifies the host key, then
`nixos-rebuild switch --flake .#<host> --target-host root@<ip>` (built
locally / on the lab builders, copied over). Finish with a reboot: a
switch does not change the kernel hostname, so until then the host still
calls itself `oci-base` (and tailscale would register that name).

Smoke check afterwards: `tailscale status` shows the host under its own
name, `/run/agenix/` holds its secrets, `systemctl --failed` is empty,
`nixos-version` matches the flake revision, `passwd -S <user>` → `P`.

## 6. Day 2

- **OS change** (the common case): edit, then
  `nix develop -c neusis cloud deploy <host>` (over the tailnet; `--target
  root@<public-ip>` works too). No terranix involved.
- **Infra change** (rules, volumes, shape): `plan` → review → `apply`,
  commit the state.
- **Drift check**: `nix run .#<stack>.plan -- -detailed-exitcode`; exit 0
  = no drift, 2 = changes pending, 1 = error. Read-only; safe any time.
- **Lock down**: `publicSsh = false` on the network + `apply` removes the
  TCP 22 ingress rule (propagates in a few seconds); SSH then only over
  tailscale (break-glass: the OCI serial console). Exercised on
  2026-10-24 and reverted; the default stays open (decision §12.8).
- **Data volume**: `dataVolumeGb` attaches a block volume that survives
  instance replacement. NixOS does not format it: once, `mkfs.ext4 -L
  data /dev/sdb` on the host, then mount it declaratively
  (`fileSystems."/srv"` by label with `nofail`, see `ghost001.nix`).
- **Builder**: a host in the builders registry is reachable by its peers
  only over a shared tailnet (rogue ↔ ghost001 over cslab). Probe through
  the daemon: `nix build --max-jobs 0 --builders 'ssh-ng://nixremote@<host>
  aarch64-linux /etc/nix/remote-build-key' --expr '<trivial derivation>'`.
- **Secrets**: `agenix edit modules/secrets/<dir>/<n>.age`, `agenix
  rekey`, `git add` the rekeyed files, deploy.

## 7. Reprovision, rotate, decommission

- **Replace the instance** (new base image wanted, corrupted root):
  `nix run .#oci-anklab.terraform -- apply -replace=oci_core_instance.<host>`,
  then §5 again. Host key, secrets, reserved IP and data volume survive;
  no rekey.
- **Rotate the host key**: new key → replace the bootstrap `.age` +
  `hostPubkey` → `agenix rekey` → bootstrap against the live host.
- **Rotate the OCI API key**: new key in the console → `agenix edit` the
  three `oci*` secrets → `agenix rekey` → `home-manager switch`.
- **Rotate the state passphrase**: OpenTofu `fallback` key provider —
  new passphrase as primary, old as fallback, `apply`, drop the fallback.
- **Decommission**: remove the instance from the stack → `plan`/`apply`
  (or `.destroy` for the whole stack); remove the machine and builder
  entries, `modules/secrets/bootstrap/<host>/` and
  `modules/secrets/rekeyed/<host>/`, `agenix rekey`, delete the node
  from the tailnet, log it in `docs/porting.md`.

## 8. Consumers

`flakeModules.default` now carries the cloud surface: the five
`terranixModules`, `features.nixos.oci-guest`, `lib.cloud.mkOciBaseImage`
and `lib.cloud.mkValidateCheck`. Add `flakeModules.terranix` for the
stack runner (the terranix input, OpenTofu with the pinned OCI provider,
the repo-root guard and the `tf.env` sourcing), then write
`perSystem.terranix.terranixConfigurations.<stack>.modules` exactly as
`modules/infra/oci-anklab.nix` does.

## 9. Public hostnames via Cloudflare Tunnel (`cloudflare-leoank`)

Services on a cloud host get a public `*.leoank.me` name without opening
any inbound port: the host runs `cloudflared` for a tunnel whose ingress
rules are managed remotely, both declared in the `cloudflare-leoank`
stack. Adding a service is one attribute + `apply`; the host config does
not change.

```nix
# modules/infra/cloudflare-leoank.nix
neusis.cloudflare.tunnels.ghost001.services.whoami = {
  hostname = "whoami.leoank.me";          # must fall under neusis.cloudflare.zones
  service = "http://localhost:8080";      # the origin as seen on ghost001
  # originRequest.no_tls_verify = true;   # extra origin_request settings
};
```

Each service becomes an ingress rule (ordered, with a `http_status:404`
catch-all last) and a proxied CNAME `<hostname> → <tunnel-id>.cfargotunnel.com`
in the zone the hostname falls under (longest declared zone wins; a
hostname outside every zone fails an assertion at eval).

**Secrets (one-time):**

1. In the operator tf.env (`agenix edit modules/secrets/ank/ociTfEnv.age`,
   then `agenix rekey` + `home-manager switch`), add
   `TF_VAR_cloudflare_api_token=…` — an API token with *Zone › Zone › Read*
   and *Zone › DNS › Edit* on leoank.me plus *Account › Cloudflare Tunnel ›
   Edit* — and `TF_VAR_cloudflare_account_id=…` (dashboard → account
   overview).
2. `nix run .#cloudflare-leoank.plan` → `.apply` creates the tunnel (and
   the records, once services exist). Commit `infra/cloudflare-leoank/terraform.tfstate`.
3. The host's tunnel token, from the stack into an agenix secret without
   touching the terminal:

   ```bash
   nix run .#cloudflare-leoank.terraform -- output -raw tunnel_token_ghost001 > /tmp/t \
     && agenix edit -i /tmp/t modules/secrets/ank/cfTunnelGhost001.age && rm -f /tmp/t
   agenix rekey && git add modules/secrets/rekeyed
   nix develop -c neusis cloud deploy ghost001
   ```
   (`cfTunnelGhost001.age` holds a placeholder until then, so the config
   evaluates; the `cloudflared-tunnel` unit just restarts until the real
   token lands.)

Afterwards `systemctl status cloudflared-tunnel` on the host shows the
connector registered, and the Zero Trust dashboard lists the tunnel as
healthy. Day 2: edit services → `plan`/`apply`; rotating the token means
rotating the tunnel (`apply -replace=cloudflare_zero_trust_tunnel_cloudflared.ghost001`)
and repeating step 3.

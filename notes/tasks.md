# Tasks

Loose todos not tied to a page. Anything tied to an experiment, run or material belongs on
that page instead.

- [ ] Add tests/machines/curiosity.test.nix (identity + bootstrap key, initrd host-key copy from SPARKDATA, n1x modules, users/homes, services, live deploy group) once curiosity stops changing by hand (AGS-20261111-h1kr9f)
- [ ] Move claude (agent-harness) to mxc confinement: rc2s2 launch profiles need a bubblewrap backend on Linux and `rc2s2 run --profile`; then wrap claude with it on both platforms (jail.nix dropped for claude 2026-11-11, AGS-20261111-h1kr9f)

---
id: AGS-20261106-2s34pz
type: agent_session
schema_version: 1
title: "Set up aerc for ank: mbsync + notmuch maildir, four accounts, agenix secrets, oama for cam.ac.uk"
model: "claude-opus-5-5"
harness: "claude-code"
started: 2026-11-06T02:32+00:00
finished: null
created_entities: [REV-20261106-2s33ep, EXP-20261106-2s4hg4]
edited_entities: []
outcome: pending          # done | failed | aborted | pending
created: 2026-11-06
author: agent:claude
---

## Task

ank asked for aerc for his user through Home Manager, with the secrets it needs, as a
terminal mail client he can automate and that his agents will later read and reply
through. His answers: four accounts (leoank98@gmail.com, ank@leoank.me,
kumar@mrclmb.ac.uk, ak2396@cam.ac.uk), app passwords, a local maildir with notmuch,
rogue only, and oama for Cambridge. Work goes under [[REV-20261106-2s33ep]].

## What happened

DNS showed leoank.me on Migadu, and cam.ac.uk on Microsoft 365, which takes only OAuth2.
ank sent MRC LMB's settings from his Mail app: `mail.mrclmb.ac.uk`, 993 and 465, user
`kumar`. oama, as built in nixpkgs, keeps tokens in the macOS keychain through
`security`. isync's `withCyrusSaslXoauth2` wraps mbsync with the XOAUTH2 plugin.

Built: `homeModules.mail-sync` (launchd/systemd, `mbsync -a; notmuch new` every 300 s)
with its test; `hmBundles.mail` in `modules/users/ank/mail.nix` on rogue; placeholder
secrets `mailGmail`, `mailMigadu` and `mailMrclmb`, encrypted to the master pubkey
only; the oama config; a `test-mail` invariant in rogue's machine test; ADR-0019
(proposed); [[EXP-20261106-2s4hg4]] for the Cambridge sign-in. T0 passes 325/325 on
both test sets. aerc, notmuch, oama and the XOAUTH2-wrapped mbsync build. The rogue home
can't build until ank fills the secrets and runs `agenix rekey`; the error is "Rekeyed
secret for age.secrets.mailGmail not found", as expected.

After the first switch, leoank and mrclmb synced; gmail and cam didn't, and aerc
showed no message body. gmail: the XOAUTH2 SASL plugin is visible to every account,
and mbsync preferred it where Gmail offers it, so it sent the app password as a bearer
token. The failed command (base64, with the password) went to the world-readable
`/tmp/mail-sync.err.log` on every run. cam: oama has no token in the keychain yet. aerc:
Home Manager's `aerc.conf` replaces aerc's own, which is where the `[filters]` live.
Fixed in `mail.nix`:
- the password accounts sign in with PLAIN, and logs go to `~/Library/Logs`;
- aerc gets its filters back, plus a 16-colour styleset and layout settings;
- MRC LMB's sieve folders aren't synced, and Gmail's trash maps to `[Gmail]/Bin`;
- `create = "both"`, because aerc's archive would otherwise strand mail in a local-only
  folder.

`docs/mail/aerc.md` is the guide. `mbsync -l gmail` with the built config lists the
folders.

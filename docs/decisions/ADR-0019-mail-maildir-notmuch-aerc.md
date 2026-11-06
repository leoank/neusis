# ADR-0019: ank's mail is a local maildir: mbsync syncs it, notmuch indexes it, aerc reads it, and agents work on it through notmuch

Status: proposed
Date: 2026-11-06

## Context
ank wants a terminal mail client he can automate, and later wants agents to read and
reply to his mail through it. Four accounts, on four kinds of server:

| Account | Server | Sign-in |
|---|---|---|
| ank@leoank.me | Migadu | mailbox password |
| leoank98@gmail.com | Gmail | Google app password |
| kumar@mrclmb.ac.uk | MRC LMB's own (`mail.mrclmb.ac.uk`) | password |
| ak2396@cam.ac.uk | Microsoft 365 | OAuth2 only: Microsoft turned off passwords for IMAP and SMTP |

Alternatives considered:
- **aerc straight over IMAP.** Least setup, but every read is a round trip, nothing works
  offline, and an agent would need the IMAP passwords to read anything.
- **A local maildir** (chosen). mbsync keeps a copy of every account; notmuch gives one
  fast full-text index over all four; aerc reads the maildir through notmuch and sends
  over SMTP. An agent reads and searches with `notmuch search` / `notmuch show` without
  holding a password.
- **OAuth2 for every account.** Gmail and Migadu take a password, and an app password is
  far simpler than a Google Cloud client. Only Microsoft 365 forces OAuth2.

## Decision
- An ank home bundle, `hmBundles.mail` (`modules/users/ank/mail.nix`), on rogue only:
  the four accounts in `accounts.email`, each synced by mbsync, indexed by notmuch and
  read in aerc. mbsync creates a folder made on either side on the other (aerc's
  archive moves into a local Archive folder, which must reach the server), and passes
  deletes and moves made in aerc back to the server; it never removes a folder on
  either side. The password accounts sign in with PLAIN: the XOAUTH2 plugin is visible
  to all of them, and mbsync would otherwise offer Gmail the password as a token.
- A reusable `homeModules.mail-sync` runs `mbsync -a; notmuch new` every five minutes
  (a launchd agent on Darwin, a systemd user timer on Linux; Home Manager's
  `services.mbsync` is Linux-only). The index runs even when one account fails.
- The three passwords are agenix secrets (`mailMigadu`, `mailGmail`, `mailMrclmb`),
  decrypted to fixed paths under `~/.config/mail/` and read with `cat`.
- The Microsoft 365 account signs in through oama. Its refresh token lives in the macOS
  login keychain, never in git, because Microsoft rotates it. oama uses the device-code
  flow with Thunderbird's public client id; whether Cambridge's tenant allows that is
  EXP-20261106-2s4hg4. mbsync gets XOAUTH2 from the cyrus-sasl-xoauth2 plugin.
- Gmail syncs every label except All Mail, Important and Starred, which would copy each
  message a second time. Gmail and Exchange save their own sent mail, so aerc doesn't
  copy it to Sent for those two.

## Consequences
- Mail works offline, and notmuch searches every account at once. The first sync
  downloads each account's full history, so it takes a while and uses disk.
- Gmail mail that was archived without a label isn't synced, because it lives only in
  All Mail.
- An agent reading mail needs only the maildir and notmuch. Replying needs an SMTP send,
  and sending as ank is a separate decision, made when the agents' access is designed.
- The Cambridge account depends on Cambridge's tenant allowing Thunderbird's client id.
  If it doesn't, the fallback is to forward that mail to another account.

---
id: EXP-20261106-2s4hg4
type: experiment
schema_version: 1
title: Does oama device-code sign-in with Thunderbird client id authorize ak2396@cam.ac.uk for IMAP and SMTP?
project: PRJ-0001
status: planned           # planned | active | paused | concluded | abandoned
outcome: null             # null | positive | negative | inconclusive | infra
influenced_by: []
created: 2026-11-06
author: agent:claude
protocols: []
materials: []
tags: [mail]
review: pending
---

## Question
Microsoft 365 refuses passwords for IMAP and SMTP, so ak2396@cam.ac.uk needs an OAuth2
token (ADR-0019). Will Cambridge's tenant let oama sign in with Thunderbird's public
client id (`9e5f94bc-e8a4-4e73-b8be-63364c29d753`) through the device-code flow, and do
the tokens it hands out work for mbsync (IMAP, XOAUTH2) and aerc (SMTP, XOAUTH2)?

## Hypothesis and predictions
Universities that allow Thunderbird have consented to its client id, so the device-code
sign-in should pass Cambridge's login and MFA, and Microsoft should return a refresh
token with the IMAP and SMTP scopes. If the tenant blocks the app or the device-code
flow, the sign-in page will say that an admin has to approve it (AADSTS65001 or
AADSTS50105).

## Plan
1. After the switch to the `mail` bundle on rogue, run `oama authorize microsoft
   ak2396@cam.ac.uk --device`. Open the page it prints, enter the code, and sign in
   with Raven and MFA. (Without `--device`, oama runs the auth-code flow against the
   device-code endpoint and waits forever: first attempt, 2026-11-06.)
2. `oama access ak2396@cam.ac.uk` prints an access token. This checks the keychain
   store, not the token.
3. `mbsync cam` syncs the Inbox, which tests IMAP XOAUTH2 through the SASL plugin.
4. From aerc, on the `cam` account, send a message to leoank98@gmail.com, which tests
   SMTP XOAUTH2.
5. A day later, `oama access` still works without a browser, which shows the refresh
   token renews.

## Success criteria
Steps 2–5 all succeed. Any AADSTS refusal at step 1 is a negative outcome, and the
fallback is to forward Cambridge mail to another account.

## Runs
One line per run after its link, what was tried and what it showed; `yajna validate`
rejects a bare link here. Metric runs also land in results.tsv.

## Conclusion
Written once, by a human, when status becomes `concluded`.

# GitHub bot for auto-updates — setup guide

**Status:** needed before M4 (the update and promotion pipelines,
`docs/auto-update-spec.md` §15). Nothing reads these settings yet.

**Audience:** Ankur, as owner of `leoank/neusis`. Every step happens on
github.com or with `gh` from a machine logged in as `leoank`.

**Why:** the pipelines must push lock bumps to `main` and move the
`deploy/<group>` branches. They do that as a **GitHub App** (the bot),
not as you: its tokens last an hour, it is installed on this one repo,
and a ruleset can let *only* the bot move `deploy/*` (spec §10). The bot
also **signs** its commits with its own SSH key, because hosts deploy
only commits signed by a key in `modules/registry/signers/` (spec §5).
The App can move branches but cannot sign; the signing key can sign but
cannot push. A leak of one is not enough.

**What you end up with:**

| Name | Kind | Holds | Used by |
|---|---|---|---|
| `APP_ID` | repository variable | the App's numeric ID | every pipeline, to mint a token |
| `APP_PRIVATE_KEY` | repository secret | the App's private key (`.pem`) | same |
| `auto-update` | environment, `main` only | — | the job that commits lock bumps |
| `BOT_SIGNING_KEY` | secret in `auto-update` | the bot's ed25519 SSH private key | same |
| `POSTMARK_API_KEY` | repository secret | Postmark server token | alerts (already added) |
| `deploy-branches`, `main` | rulesets | who may move which branch | GitHub |

At the end you send me two things (§7): the App's **name** and the
signing key's **public** line.

---

## 1. Create the App

Open **https://github.com/settings/apps/new** (your account → Settings →
Developer settings → GitHub Apps → New GitHub App).

- **GitHub App name:** names are global, so `neusis-bot` may be taken.
  Try `leoank-neusis-bot`. The commit author becomes `<name>[bot]`.
- **Homepage URL:** `https://github.com/leoank/neusis`.
- **Identifying and authorizing users:** leave the callback URL empty,
  and leave *Request user authorization (OAuth) during installation*
  unchecked. The bot never acts for a user.
- **Post installation:** leave empty.
- **Webhook:** **uncheck *Active*.** The bot only reacts to workflow
  runs; it needs no events delivered anywhere.
- **Repository permissions** (everything else stays *No access*):

  | Permission | Access | Why |
  |---|---|---|
  | Contents | Read and write | push lock bumps to `main`, move `deploy/*` |
  | Issues | Read and write | the rolling failure issues (spec §6.4) |
  | Pull requests | Read and write | reserved for bump PRs if `main` ever requires them |
  | Actions | Read-only | read gate results when promoting |
  | Metadata | Read-only | mandatory, set automatically |

  Leave **Workflows** at *No access*. A push that changes
  `.github/workflows/` then fails, so a stolen App token can't rewrite
  the pipelines. Lock bumps never touch them.
- **Organization and account permissions:** none.
- **Subscribe to events:** none.
- **Where can this GitHub App be installed?** *Only on this account.*

Click **Create GitHub App**.

## 2. App ID and private key

On the App's **General** page:

1. Note the **App ID**, a number near the top. The *Client ID*
   (`Iv23…`) is a different value and isn't the one we need.
2. Under **Private keys**, click **Generate a private key**. A file
   `<name>.<date>.private-key.pem` downloads.

Store both, then delete the downloaded key:

```bash
gh variable set APP_ID --repo leoank/neusis --body <app-id>
gh secret set APP_PRIVATE_KEY --repo leoank/neusis < ~/Downloads/<name>.*.private-key.pem
rm -f ~/Downloads/<name>.*.private-key.pem
```

You don't need a local copy. If the key is ever lost or leaked, generate
a new one on the same page, run `gh secret set` again, and delete the
old key there.

## 3. Install it on the repo

In the App's left sidebar, open **Install App** and click **Install**
next to `leoank`. Choose **Only select repositories**, select
`leoank/neusis`, then **Install**.

The repo's **Settings → GitHub Apps** page now lists it.

## 4. Signing key and the `auto-update` environment

The key is created in a throwaway directory, uploaded, and deleted. Only
GitHub keeps the private half.

```bash
d=$(mktemp -d)
ssh-keygen -t ed25519 -N '' -C 'neusis-bot signing' -f "$d/bot_signing"

# The environment, deployable from main only.
gh api -X PUT repos/leoank/neusis/environments/auto-update \
  -F 'deployment_branch_policy[protected_branches]=false' \
  -F 'deployment_branch_policy[custom_branch_policies]=true'
gh api -X POST repos/leoank/neusis/environments/auto-update/deployment-branch-policies \
  -f name=main -f type=branch

gh secret set BOT_SIGNING_KEY --repo leoank/neusis --env auto-update < "$d/bot_signing"

cat "$d/bot_signing.pub"   # send me this line (§7)
rm -rf "$d"
```

The key has no passphrase because CI can't type one. The environment
is what protects it: only a job that runs from `main` and names
`environment: auto-update` can read it.

Under **Settings → Environments → auto-update**, *Deployment branches and
tags* should now show *Selected branches and tags: main*. Leave
*Required reviewers* off, or every daily bump would wait for you.

**Rotation:** make a new key the same way, put its public line in
`modules/registry/signers/anklab.nix` next to the old one, commit
(signed by you), let it deploy, then remove the old line. Hosts verify
with the signers of the config they are running, so the new key has to
be live everywhere before it signs anything.

## 5. Rulesets

Open **Settings → Rules → Rulesets → New ruleset → New branch ruleset**
twice.

**`deploy-branches`:**
- Enforcement status: **Active**.
- Bypass list: **Add bypass** → the App → *Always allow*. This is risk R5
  in the spec. If the App isn't offered on a personal-account repo,
  stop here and tell me; promotion then needs another design.
- Target branches: **Add target → Include by pattern → `deploy/*`**.
- Rules: **Restrict creations**, **Restrict updates**, **Restrict
  deletions**, **Block force pushes**.

Only the bot can create or move a deploy branch, and it can only
fast-forward one.

**`main`:**
- Enforcement status: **Active**, with no bypass list.
- Target branches: **Include default branch**.
- Rules: **Restrict deletions** and **Block force pushes** only.

Your direct pushes to `main` keep working. **Don't enable *Require signed
commits*.** It demands signatures GitHub can *verify*, and GitHub can't
verify the bot's: a bot account can't register an SSH signing key, so
its commits show *Unverified* (spec §5). The ruleset would reject every
bump. comin enforces signatures on the hosts instead.

## 6. Postmark (the alert email)

The `POSTMARK_API_KEY` secret is set. Two Postmark-side steps are left:

1. **Sender:** under *Sender Signatures*, add and confirm
   `ghcibot@leoank.me`, or verify the whole `leoank.me` domain (DKIM and
   Return-Path DNS records). Postmark rejects any other `From`.
2. **Account approval:** a new Postmark account only delivers to
   addresses on the sender's own domain. Mail to `leoank98@gmail.com`
   works only after you request approval (*Account → Request approval*)
   and Postmark grants it.

To send a test, read the token without echoing it, so it stays out of
shell history:

```bash
read -rs POSTMARK_API_KEY && export POSTMARK_API_KEY
ALERT_FROM=ghcibot@leoank.me ALERT_TO=leoank98@gmail.com \
  nix run .#neusis-notify -- --title 'neusis: test alert' 'Postmark works.'
```

Exit status 0 means Postmark accepted the message. A 422 means the
sender isn't confirmed or the account isn't approved for that
recipient yet.

## 7. Check and hand over

```bash
gh variable list --repo leoank/neusis                     # APP_ID
gh secret list --repo leoank/neusis                       # APP_PRIVATE_KEY, POSTMARK_API_KEY
gh secret list --repo leoank/neusis --env auto-update     # BOT_SIGNING_KEY
gh api repos/leoank/neusis/rulesets --jq '.[].name'       # deploy-branches, main
```

Then send me:

- **the App name** (its slug, as in `github.com/apps/<slug>`). The
  pipelines commit as `<slug>[bot]`, with the noreply address derived
  from the bot account's ID;
- **the signing key's public line** (`ssh-ed25519 AAAA… neusis-bot
  signing`). It goes into `modules/registry/signers/anklab.nix`, in a
  commit you sign, with the bot's commit address as its principal:
  `git verify-commit` matches the principal against the committer email.

Neither is secret.

## Revoking everything

To shut the bot out at once, uninstall the App (repo **Settings → GitHub
Apps → Configure → Uninstall**) and delete `BOT_SIGNING_KEY`. Hosts stop
accepting bot-signed commits only after the signer is removed from the
registry and that change has deployed. Until then, `DEPLOY_HOLD` (spec
§4.3) freezes the deploy branches.

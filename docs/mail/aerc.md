# Mail with aerc

ank's four mail accounts are on rogue as a local maildir (ADR-0019). mbsync copies them
into `~/Maildir` every five minutes and notmuch indexes them. aerc reads that copy and
sends through each account's own SMTP server. The setup is
[`modules/users/ank/mail.nix`](../../modules/users/ank/mail.nix).

| aerc tab | Address | Sign-in |
|---|---|---|
| `leoank` (default) | ank@leoank.me | Migadu password, secret `mailMigadu` |
| `gmail` | leoank98@gmail.com | Google app password, secret `mailGmail` |
| `mrclmb` | kumar@mrclmb.ac.uk | MRC LMB password, secret `mailMrclmb` |
| `cam` | ak2396@cam.ac.uk | Microsoft OAuth2 through oama, token in the login keychain |

---

## 1. Getting around

Start it with `aerc`. Each account has its own tab, with folders on the left and messages
on the right. `?` lists every key, and `:` opens the command line, which completes with Tab.

| Keys | What |
|---|---|
| `<C-n>` / `<C-p>` | next / previous account tab |
| `j` / `k`, `g` / `G` | next / previous message, first / last |
| `J` / `K` | next / previous folder |
| `<Enter>` | open the message |
| `T`, `<Tab>` | threads on/off, fold or unfold the thread |
| `<Space>`, `v`, `V` | mark and move on, mark, mark a range |
| `/`, `n` / `N` | search, next / previous match |
| `\` | filter the list (`:clear` or `<Esc>` drops it) |
| `d`, `D` | delete with confirmation, delete now |
| `a` | archive (see §4 for Gmail) |
| `c` | change folder (`:cf`) |
| `<C-t>` | a terminal tab, `q` quits |

## 2. Reading

`<Enter>` opens a message, and its text part is shown in `less`. When a message has only
HTML, aerc renders it as text through w3m and loads no remote images. `<C-j>` / `<C-k>`
move between parts, `o` opens the current part in the macOS app for it (a browser for
HTML, Preview for a PDF), and `S` saves it. `<C-l>` opens a link and `<C-y>` copies one.
`H` shows all headers, `J` / `K` go to the next / previous message, and `q` closes.

Anything aerc shows can also go through a shell command: `|` pipes the message to a
command, e.g. `| bat -l email`.

## 3. Writing

| Keys | What |
|---|---|
| `C` or `m` | new message |
| `rr` / `rq` | reply all / reply all quoting the message |
| `Rr` / `Rq` | reply to the sender / the same, quoting |
| `f` | forward |

The editor is `$EDITOR`. After you save and quit it, aerc shows a review screen:
`y` sends, `e` edits again, `a` attaches a file, `p` postpones to Drafts, and `q`
discards or postpones. `<C-j>` / `<C-k>` move between the header fields, and `<C-o>`
completes an address. The sender is the account whose tab you're on;
`<A-n>` / `<A-p>` switch it while composing.

## 4. Sync, folders and deleting

- New mail arrives within five minutes. To fetch now: `mbsync -a && notmuch new`, or
  `mbsync gmail` for one account.
- A delete or a move in aerc reaches the server on the next sync. Deleted mail goes to
  the account's trash folder (`[Gmail]/Bin` on Gmail).
- Archiving (`a`) moves a message into the account's `Archive` folder, which the next
  sync creates on the server if it isn't there. On Gmail that folder is a label called
  Archive. Gmail's own archive is All Mail, which, like Important and Starred, isn't
  synced, because every message in it is already in another folder.
- Sent mail: Migadu and MRC LMB save a copy in the account's Sent folder. Gmail and
  Microsoft 365 save their own copy, so aerc doesn't add one.
- The sync log is `~/Library/Logs/mail-sync.err.log` (and `.out.log`).

## 5. Searching everything with notmuch

notmuch indexes all four accounts together, from the shell as well as from aerc:

```sh
notmuch search from:alice date:30d..       # threads, newest first
notmuch search tag:unread folder:/gmail/   # unread Gmail
notmuch show --format=text thread:0000…    # read one
notmuch count 'subject:invoice'
```

In aerc, `:query <notmuch query>` opens the results as a folder, and `/` searches the
current one. Agents read mail the same way: notmuch only needs the maildir, not the
passwords.

## 6. Signing in, and when an account stops

- **Cambridge (once, and again if it stops):**
  `oama authorize microsoft ak2396@cam.ac.uk --device`. It prints
  `https://login.microsoft.com/device` and a code. Open the page, enter the code, sign in
  with Raven, and oama finishes by itself a few seconds later. Without `--device`,
  oama starts a different flow, "Visit http://localhost:…/start", which waits for a
  redirect that Microsoft's device-code endpoint never sends. After that,
  `oama access ak2396@cam.ac.uk` returns a token without asking again. Whether
  Cambridge allows this sign-in is EXP-20261106-2s4hg4.
- **A password changed:** `agenix edit modules/secrets/ank/<secret>.age` (secret names
  are in the table above), then `agenix rekey -a` and switch.
- **Gmail says "Invalid credentials":** the app password was revoked or mistyped. Make a
  new one under Google Account → Security → App passwords, then do the step above.
- **An account doesn't sync:** `mbsync <tab name>` shows its error, and
  `mbsync -l <tab name>` lists the folders the server offers.
- **A message shows no text:** check that its type has a filter in the `[filters]`
  section of `programs.aerc.extraConfig` in `mail.nix`. HTML is `text/html`.

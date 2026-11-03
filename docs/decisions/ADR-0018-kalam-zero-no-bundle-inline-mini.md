# ADR-0018: kalam-zero has no plugin bundle; it inlines the mini.nvim modules it needs (editing set, mini.pick, mini.clue), active on Neovim 0.10+

Status: accepted (supersedes ADR-0016's plugin bundle; the rest of ADR-0016 stands)
Date: 2026-11-03

## Context
ADR-0016 planned a tarball of vendored pure-Lua plugins (phase 4) next to the single
file. ADR-0017 then showed that pure-Lua plugins can travel inside the file. The
remaining question was which plugins would still need the tarball. Measured on kalam's
pins:

| Plugin | Oldest Neovim | Lua | Runtime files |
|---|---|---|---|
| mini.nvim 0.17 | 0.10 | one file per module, 12–156 KB | none |
| which-key 3.17 | 0.9.4 | 164 KB, 26 files | `plugin/` |
| snacks.nvim 2.31 | 0.10, parts 0.11.4 | 1.3 MB, 126 files | `plugin/`, `queries/` |

The 380 KB file with oil takes ~15 ms to source on nvim 0.12.4, against 0.03 ms for an
empty config. Everything is parsed at startup, so inlining is paid for in size and time
by every machine, including the ones too old to run the plugin.

Alternatives considered:
- **Keep the bundle** for plugins that need runtime files. The only such candidates,
  snacks and which-key, either have a smaller mini equivalent or wouldn't suit these
  machines.
- **Inline everything kalam uses.** About 4 MB and roughly 100 ms of startup, mostly for
  plugins an 0.8 or 0.9 machine can't run.

## Decision
- No tarball. Phase 4 of ADR-0016 becomes inlining selected mini.nvim modules, with the
  mechanism of ADR-0017, restricted to the chosen module files:
  - the editing set base already has: surround (on base's `gs…` keys), pairs, move,
    bracketed, splitjoin;
  - **mini.pick**: the find, buffer, recent, help and grep shortcuts use it instead of
    `:find` / `vim.ui.select` / `:grep`, and it also serves `vim.ui.select`;
  - **mini.clue**: which-key's job, with base's leader groups.
- They are set up only on Neovim 0.10+. On 0.8 and 0.9 the built-in fallbacks of
  ADR-0016 stay in charge.
- Not inlined: snacks and which-key (above), mini.files (oil covers it), mini.sessions
  (zero writes the same `.nvim.session`), mini.icons (needs a Nerd Font, rare on these
  terminals), mini.comment (`gc` is built in from 0.10), hipatterns.

## Consequences
- The file grows to roughly 900 KB, and startup to an estimated 30 ms.
- On 0.10+, zero feels close to kalam for editing and finding. On 0.8/0.9 it stays the
  built-in version, and the tests cover both.
- The picker itself is interactive, so the headless test can only check that mini.pick
  is loaded and the shortcuts use it, not drive a pick.

---
id: REV-20261103-hv2prm
type: review
schema_version: 1
title: kalam-zero build, phases 1–5 (ADR-0016 to ADR-0018)
project: PRJ-0001
target:
  kind: range               # branch | range | page | run | experiment | phase
  ref: c7b40fa..d55dc55
base: c7b40faaec6f95ae93d947a90b4be0c5c9f0e7d0
head: d55dc55f618da0a6eab9786e2707616ad96db942
paths: []
about: [PRJ-0001, EXP-20261103-g9kpxs, RUN-20261103-g9nmnp, RUN-20261103-h3sjsx]             # the pages it is about: experiments, runs, a project
status: changes_requested # open | changes_requested | approved | merged | closed
created: 2026-11-03
author: agent:claude
---

## Summary
The whole kalam-zero build: phases 1 to 5 of [[PRJ-0001]]'s Progress, commits `8100ee4`..`d55dc55` on top of the design commit `c7b40fa` (ADR-0016).
- **Phases 1–2:** the zero flavour, `kalam-zero-init` and the built-in fallbacks.
- **ADR-0017:** oil.nvim inlined into the file.
- **Phase 3:** the headless test on the official Neovim 0.8.3–0.11.7 releases, in CI ([[RUN-20261103-h3sjsx]]).
- **Phase 4 (ADR-0018):** mini inlined; no plugin bundle.
- **Phase 5:** the rolling release and `docs/kalam/zero.md`.

Evidence:
- [[EXP-20261103-g9kpxs]] with [[RUN-20261103-g9nmnp]] and [[RUN-20261103-h3sjsx]]. The headless test runs 104 checks on 0.8/0.9 and 121 on 0.10–0.12.
- The first release run (GitHub Actions 41672011730) passed. The published `init.lua` matches its published checksum, and the file downloaded from the release URL passes 121 checks locally.

Threads opened by the agent from its own read-through: one security issue (session autoload), one release-ordering issue, one reproducibility issue, and smaller questions. Approving and resolving are ank's.
- 2026-11-03 16:20 ank requested changes: Also add instructions for a windows machine on the release page
- 2026-11-03 17:16 ank requested changes: Also, running nix run .#kalam-zero is builds the package, but it is broken because of snacks.statuscolumn doesn't exisit. and the error just keep popping up continuously making the whole thing unsuable.

## Threads

### T1 (open) modules/packages/kalam/_flavors/zero/config/zero.lua:186-192 @ d55dc55
```lua
vim.api.nvim_create_autocmd("VimEnter", {
  group = aug,
  nested = true,
  callback = function()
    if vim.fn.argc() == 0 and vim.fn.filereadable(Z.session_file) == 1 then Z.session_load() end
  end,
})
```
- 2026-11-03 16:15 agent:claude: Security: a bare nvim auto-sources ./.nvim.session, and a session file is Vimscript. zero turned exrc off because a machine you ssh into may hold someone else's files, but this autoload has the same exposure: cd into another user's folder that contains a .nvim.session, start nvim, and it runs. Proposal: autoload only when the file is owned by the current user (vim.loop.fs_stat(...).uid == vim.loop.getuid()) and was written by zero (mksession adds a recognisable header); otherwise leave <leader>ql as the explicit opt-in.
- 2026-11-03 17:23 ank: make the session load manual by default. and add your suggested fixes for autoload session

### T2 (open) .github/workflows/kalam-zero-release.yml:76-84 @ d55dc55
```yml
          EOF
          git tag -f kalam-zero HEAD
          git push -f origin refs/tags/kalam-zero
          if gh release view kalam-zero > /dev/null 2>&1; then
            gh release edit kalam-zero --notes-file notes.md
          else
            gh release create kalam-zero --title "kalam-zero" --notes-file notes.md --latest=false
          fi
          gh release upload kalam-zero init.lua init.lua.sha256 --clobber
```
- 2026-11-03 16:15 agent:claude: Correctness: cancel-in-progress plus a tag move before the upload. If a newer push cancels this run after 'git push -f ... refs/tags/kalam-zero' but before 'gh release upload', the tag points at the new commit while the release still serves the old init.lua and sha256 (the next run fixes it, but the notes and checksum disagree in between). Proposal: upload first and move the tag last, or set cancel-in-progress: false for this group so a run that has started publishing finishes.
- 2026-11-03 17:09 ank: follow your proposal

### T3 (open) modules/packages/kalam/_flavors/zero/config/default.nix:32-36 @ d55dc55
```nix
    # Set in zero.lua only when the terminal advertises truecolor.
    termguicolors = lib.mkForce false;
    # base's 300 ms is tuned for which-key's popup; without it, three-key
    # leader sequences need more time.
    timeoutlen = lib.mkForce 800;
```
- 2026-11-03 16:15 agent:claude: Question: timeoutlen is 800 everywhere because ADR-0016 assumed no which-key popup. Since ADR-0018, 0.10+ has mini.clue, which shows the next keys after 300 ms on its own, so 800 only slows down non-trigger multi-key maps there. Set vim.o.timeoutlen = 300 in zero.lua when Z.mini.clue loaded, and keep 800 for 0.8/0.9?
- 2026-11-03 17:20 ank: change it to 300ms when mini.clue is loaded. good catch!

### T4 (open) modules/packages/kalam/_flavors/zero/config/zero.lua:82-97 @ d55dc55
```lua
local function b64(data) -- vim.base64 is 0.10+
  return ((data:gsub(".", function(x)
    local r, byte = "", x:byte()
    for i = 8, 1, -1 do r = r .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and "1" or "0") end
    return r
  end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
    if #x < 6 then return "" end
    local c = 0
    for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
    return b64chars:sub(c + 1, c + 1)
  end) .. ({ "", "==", "=" })[#data % 3 + 1])
end
function Z.osc52_copy(lines)
  local seq = "\027]52;c;" .. b64(table.concat(lines, "\n")) .. "\007"
  if vim.env.TMUX then seq = "\027Ptmux;" .. seq:gsub("\027", "\027\027") .. "\027\\" end
  vim.fn.chansend(vim.v.stderr, seq)
```
- 2026-11-03 16:15 agent:claude: Performance: the hand-written base64 builds a bit string per byte, so OSC 52 on a large yank (a few MB) will stall noticeably. vim.base64.encode exists from 0.10; use it when present and keep this for 0.8/0.9. Terminals also cap OSC 52 payloads (often ~100 KB), so a size limit with a message would be friendlier than a silent truncation.
- 2026-11-03 17:21 ank: do this.

### T5 (open) modules/packages/kalam/_flavors/zero/config/zero.lua:106-111 @ d55dc55
```lua
  local function paste() return { vim.fn.split(vim.fn.getreg('"'), "\n"), vim.fn.getregtype('"') } end
  vim.g.clipboard = {
    name = "kalam-zero OSC 52",
    copy = { ["+"] = Z.osc52_copy, ["*"] = Z.osc52_copy },
    paste = { ["+"] = paste, ["*"] = paste },
  }
```
- 2026-11-03 16:15 agent:claude: Behaviour to confirm: with the OSC 52 provider, <leader>p pastes the unnamed register, not the local clipboard, because few terminals answer OSC 52 paste requests. So copying out works, pasting in needs the terminal's own paste (Cmd-V). docs/kalam/zero.md doesn't say so; worth a line in §5 if this is the intended behaviour.
- 2026-11-03 17:22 ank: Add that line.

### T6 (open) general
- 2026-11-03 16:15 agent:claude: Coverage gaps, for the record (RUN-20261103-h3sjsx Notes): no LSP server in the sandbox, so the LspAttach shortcuts are untested; pickers are interactive, so the test only checks the shortcuts reach mini.pick; OSC 52 is checked by the escape sequence, not a terminal; no macOS or arm64 release builds below 0.10.

### T7 (open) modules/packages/kalam/kalam.nix:54-66 @ d55dc55
```nix
          (cd ${plugin}/lua && ${
            if files == null then "find ${name} -name '*.lua' | sort" else "printf '%s\n' ${toString files}"
          }) | while read -r f; do
            mod=''${f%.lua}; mod=''${mod%/init}; mod=''${mod//\//.}
            printf 'package.preload["%s"] = function(...)\n' "$mod"
            cat "${plugin}/lua/$f"
            printf '\nend\n'
          done
          if [ -d ${plugin}/syntax ]; then
            echo 'do'
            echo '  local dir = vim.fn.tempname() .. "-kalam-zero"'
            echo '  vim.fn.mkdir(dir .. "/syntax", "p")'
            for s in ${plugin}/syntax/*.vim; do
```
- 2026-11-03 16:16 agent:claude: Reproducibility: the published init.lua (built on x86_64-linux, sha256 a3ba2aa0…) and a local aarch64-darwin build (88559b4f…) differ only in the order of oil's two syntax files: the shell glob and 'find | sort' collate oil.vim vs oil_preview.vim by locale. Harmless at runtime, but the same commit should give the same bytes on every system, so the published checksum can be checked against a local build. Proposal: export LC_ALL=C at the top of the kalam-zero-init runCommand, and a check that compares the two systems' outputs.
- 2026-11-03 17:24 ank: go with your proposal

### T8 (open) .github/workflows/kalam-zero-release.yml:79-83 @ d55dc55
```yml
          if gh release view kalam-zero > /dev/null 2>&1; then
            gh release edit kalam-zero --notes-file notes.md
          else
            gh release create kalam-zero --title "kalam-zero" --notes-file notes.md --latest=false
          fi
```
- 2026-11-03 16:16 agent:claude: Minor: --latest=false doesn't help while kalam-zero is the repo's only release; GitHub's releases/latest resolves to it (checked: tag_name kalam-zero). The first CLI v* release will take latest over. If that matters before then, mark it --prerelease instead.
- 2026-11-03 17:08 ank: leave it for now. only make a note.

### T9 (open) docs/kalam/zero.md#5. Troubleshooting @ d55dc55
```md
## 5. Troubleshooting
```
- 2026-11-03 16:16 agent:claude: Docs gap, found while verifying the release: VIMINIT overrides init.lua. A nixvim-wrapped Neovim (kalam itself) exports VIMINIT into its :terminal, so running 'NVIM_APPNAME=kalam nvim' inside kalam's terminal loads kalam's config, not zero's, and fails on missing plugins. Worth a troubleshooting line ('env -u VIMINIT NVIM_APPNAME=kalam nvim'), and maybe zero should warn when VIMINIT is set.
- 2026-11-03 17:19 ank: add this

### T10 (open) .github/workflows/kalam-zero-release.yml:69-73 @ d55dc55
```yml
          \`\`\`sh
          curl -fsSL https://github.com/${{ github.repository }}/releases/download/kalam-zero/init.lua \\
            --create-dirs -o ~/.config/kalam/init.lua
          NVIM_APPNAME=kalam nvim        # Neovim 0.8: nvim -u ~/.config/kalam/init.lua
          \`\`\`
```
- 2026-11-03 17:06 ank: Add instruction for a windows machine as well

### T11 (open) docs/kalam/zero.md:17-19 @ d55dc55
```md
curl -fsSL https://github.com/leoank/neusis/releases/download/kalam-zero/init.lua \
  --create-dirs -o ~/.config/kalam/init.lua
NVIM_APPNAME=kalam nvim
```
- 2026-11-03 17:11 ank: Add a windows section as well

### T12 (open) docs/kalam/zero.md:118 @ d55dc55
```md
## 4. Different from kalam
```
- 2026-11-03 17:18 ank: Add an option to load custom lua config that sits next to init.lua file inside a "lua" dir. This will enable users to add custom configs in a pinch.

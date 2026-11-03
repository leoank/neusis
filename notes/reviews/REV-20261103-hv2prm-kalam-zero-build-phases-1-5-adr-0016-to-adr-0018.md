---
id: REV-20261103-hv2prm
type: review
schema_version: 1
title: kalam-zero build, phases 1–5 (ADR-0016 to ADR-0018)
project: PRJ-0001
target:
  kind: range               # branch | range | page | run | experiment | phase
  ref: c7b40fa..32eb056d159c1330c9de14c716fcb8ac753eb1af
base: c7b40faaec6f95ae93d947a90b4be0c5c9f0e7d0
head: 32eb056d159c1330c9de14c716fcb8ac753eb1af
rounds: [d55dc55f618da0a6eab9786e2707616ad96db942, a03a8f1c01d8ff8fe2460a74309f10ce2e242a99]
paths: []
about: [PRJ-0001, EXP-20261103-g9kpxs, RUN-20261103-g9nmnp, RUN-20261103-h3sjsx]             # the pages it is about: experiments, runs, a project
status: approved          # open | changes_requested | approved | merged | closed
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
- 2026-11-03 18:23 ank approved: All the tasks for the MVP is done and manually verified as well.

## Threads

### T1 (resolved) modules/packages/kalam/_flavors/zero/config/zero.lua:186-192 @ d55dc55
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
- 2026-11-03 17:36 agent:claude addressed in 0013eb1: Loading is manual by default (<leader>ql). vim.g.kalam_zero_session_autoload = true turns autoload back on, and then only for a .nvim.session the current user owns (uv.fs_stat uid) whose first line is the marker zero now writes on save. Tested headless: a marked session we own present at startup isn't run by default; Z.session_trusted accepts it and rejects an unmarked one; saving writes the marker. Docs §3 updated.
- 2026-11-03 18:07 ank resolved

### T2 (resolved) .github/workflows/kalam-zero-release.yml:76-84 @ d55dc55
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
- 2026-11-03 17:36 agent:claude addressed in fa1d78f: Both halves of the proposal: the step now uploads init.lua and its sha256 (or creates the release with them) and edits the notes before moving the tag, and the concurrency group no longer cancels a run in progress, so a newer push waits. actionlint passes; takes effect from the next release run.
- 2026-11-03 17:37 agent:claude: Follow-up 0c4e3e2: the comment in the step claimed more than the order gives. If the step stops between upload and tag push, the tag lags one commit behind the files; what it can no longer do is name a commit whose init.lua wasn't published. Comment corrected.
- 2026-11-03 18:04 ank resolved

### T3 (resolved) modules/packages/kalam/_flavors/zero/config/default.nix:32-36 @ d55dc55
```nix
    # Set in zero.lua only when the terminal advertises truecolor.
    termguicolors = lib.mkForce false;
    # base's 300 ms is tuned for which-key's popup; without it, three-key
    # leader sequences need more time.
    timeoutlen = lib.mkForce 800;
```
- 2026-11-03 16:15 agent:claude: Question: timeoutlen is 800 everywhere because ADR-0016 assumed no which-key popup. Since ADR-0018, 0.10+ has mini.clue, which shows the next keys after 300 ms on its own, so 800 only slows down non-trigger multi-key maps there. Set vim.o.timeoutlen = 300 in zero.lua when Z.mini.clue loaded, and keep 800 for 0.8/0.9?
- 2026-11-03 17:20 ank: change it to 300ms when mini.clue is loaded. good catch!
- 2026-11-03 17:39 agent:claude addressed in 44da1c4: timeoutlen = 300 once mini.clue is set up (0.10+); 800 from default.nix stays for 0.8/0.9, its comment now says so. The headless test asserts 300 on 0.10+ and 800 below.
- 2026-11-03 18:07 ank resolved

### T4 (resolved) modules/packages/kalam/_flavors/zero/config/zero.lua:82-97 @ d55dc55
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
- 2026-11-03 17:39 agent:claude addressed in 57dbccd: Z.encode is vim.base64.encode when it exists (0.10+), the hand-written encoder otherwise. Copies over 100,000 encoded bytes (~73 KB of text) send nothing and warn that the text stays in Neovim's registers. Headless: the fallback encoder matches vim.base64 on a sample with NUL, 0xFF and UTF-8 bytes; an 80 KB copy sends nothing and warns.
- 2026-11-03 18:07 ank resolved

### T5 (resolved) modules/packages/kalam/_flavors/zero/config/zero.lua:117-122 @ a03a8f1
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
- 2026-11-03 17:41 agent:claude addressed in 2c638c7: Added to §5: over OSC 52 <leader>p pastes Neovim's last yank, and pasting from the local clipboard is the terminal's paste in insert mode. Also a line for T4's new warning on copies too large for OSC 52.
- 2026-11-03 18:07 ank resolved

### T6 (resolved) general
- 2026-11-03 16:15 agent:claude: Coverage gaps, for the record (RUN-20261103-h3sjsx Notes): no LSP server in the sandbox, so the LspAttach shortcuts are untested; pickers are interactive, so the test only checks the shortcuts reach mini.pick; OSC 52 is checked by the escape sequence, not a terminal; no macOS or arm64 release builds below 0.10.
- 2026-11-03 17:43 agent:claude: No change asked for. T4 and T12 added checks (encoder, size limit, user Lua), and Windows joins the list of what no test covers; it stays a record for ank to resolve.
- 2026-11-03 18:09 ank: add a test for the lsp using the "lua" folder to add custom lsp config.
- 2026-11-03 18:19 agent:claude addressed in 32eb056: The harness installs lua/50-lsp.lua, which starts lua-language-server for Lua buffers with vim.lsp.start (0.8+), and adds the server to the check's inputs. The test opens a Lua file, then checks that lua_ls attaches, zero's LSP shortcuts are buffer-local, an undefined global is reported (and counted in the statusline), gd jumps to the definition, and rename renames both uses. It passes on 0.8.3, 0.9.5, 0.10.4, 0.11.7 and 0.12.4 (129 checks on 0.8/0.9, 146 on 0.10+). docs/kalam/zero.md §6 shows the same file and the 0.11+ vim.lsp.config/enable form; §4 points there.
- 2026-11-03 18:23 ank resolved

### T7 (resolved) modules/packages/kalam/kalam.nix:54-66 @ a03a8f1
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
- 2026-11-03 17:40 agent:claude addressed in 5aa7cd8: LC_ALL=C at the top of the kalam-zero-init build. New check checks.<system>.kalam-zero-init-matches-x86_64-linux (every system but x86_64-linux) cmp's the local file with the x86_64-linux one; it passes on aarch64-darwin (sha256 2c8a5e25…), where before this commit the two differed (88559b4f… vs the published a3ba2aa0…). It isn't in CI: the macOS job doesn't build checks that need a Linux builder.
- 2026-11-03 18:08 ank resolved

### T8 (resolved) .github/workflows/kalam-zero-release.yml:79-83 @ d55dc55
```yml
          if gh release view kalam-zero > /dev/null 2>&1; then
            gh release edit kalam-zero --notes-file notes.md
          else
            gh release create kalam-zero --title "kalam-zero" --notes-file notes.md --latest=false
          fi
```
- 2026-11-03 16:16 agent:claude: Minor: --latest=false doesn't help while kalam-zero is the repo's only release; GitHub's releases/latest resolves to it (checked: tag_name kalam-zero). The first CLI v* release will take latest over. If that matters before then, mark it --prerelease instead.
- 2026-11-03 17:08 ank: leave it for now. only make a note.
- 2026-11-03 17:37 agent:claude addressed in b8ed662: Left as is, as asked; the note sits next to --latest=false in the workflow: while kalam-zero is the only release, releases/latest resolves to it, and the CLI's first v* release takes that over.
- 2026-11-03 18:04 ank resolved

### T9 (resolved) docs/kalam/zero.md#5. Troubleshooting @ a03a8f1
```md
## 5. Troubleshooting
```
- 2026-11-03 16:16 agent:claude: Docs gap, found while verifying the release: VIMINIT overrides init.lua. A nixvim-wrapped Neovim (kalam itself) exports VIMINIT into its :terminal, so running 'NVIM_APPNAME=kalam nvim' inside kalam's terminal loads kalam's config, not zero's, and fails on missing plugins. Worth a troubleshooting line ('env -u VIMINIT NVIM_APPNAME=kalam nvim'), and maybe zero should warn when VIMINIT is set.
- 2026-11-03 17:19 ank: add this
- 2026-11-03 17:41 agent:claude addressed in 4b4242c: Troubleshooting line added (env -u VIMINIT NVIM_APPNAME=kalam nvim). The warning half isn't possible: with VIMINIT set Neovim never reads zero's init.lua, so there is no code of zero's running to warn; the doc says so.
- 2026-11-03 18:05 ank resolved

### T10 (resolved) .github/workflows/kalam-zero-release.yml:71-75 @ a03a8f1
```yml
          \`\`\`sh
          curl -fsSL https://github.com/${{ github.repository }}/releases/download/kalam-zero/init.lua \\
            --create-dirs -o ~/.config/kalam/init.lua
          NVIM_APPNAME=kalam nvim        # Neovim 0.8: nvim -u ~/.config/kalam/init.lua
          \`\`\`
```
- 2026-11-03 17:06 ank: Add instruction for a windows machine as well
- 2026-11-03 17:43 agent:claude addressed in 3e285a1: The release notes now have a Windows (PowerShell) block: create %LOCALAPPDATA%\kalam, Invoke-WebRequest the file into it, start with NVIM_APPNAME=kalam. $env: is escaped in the heredoc; rendered locally with git/gh stubbed, the notes come out as intended. The cmd.exe form and the $PROFILE function are in docs/kalam/zero.md (T11).
- 2026-11-03 18:05 ank resolved

### T11 (resolved) docs/kalam/zero.md:17-19 @ a03a8f1
```md
curl -fsSL https://github.com/leoank/neusis/releases/download/kalam-zero/init.lua \
  --create-dirs -o ~/.config/kalam/init.lua
NVIM_APPNAME=kalam nvim
```
- 2026-11-03 17:11 ank: Add a windows section as well
- 2026-11-03 17:42 agent:claude addressed in 2ca74c6: Windows section in §1: PowerShell install into %LOCALAPPDATA%\kalam (what NVIM_APPNAME=kalam reads there), a $PROFILE function so the machine's nvim stays as it is, the cmd.exe/curl.exe form, and where lua/ goes. One code change for a stock Windows: with neither rg nor grep, Z.grep uses :vimgrep (headless test forces that path). The doc says plainly it's untested on Windows: no Windows build runs the headless test.
- 2026-11-03 18:06 ank resolved

### T12 (resolved) docs/kalam/zero.md:147 @ a03a8f1
```md
## 4. Different from kalam
```
- 2026-11-03 17:18 ank: Add an option to load custom lua config that sits next to init.lua file inside a "lua" dir. This will enable users to add custom configs in a pinch.
- 2026-11-03 17:41 agent:claude addressed in b488edf: lua/*.lua next to init.lua (found from init.lua's own path, so it also works with -u) run last, sorted by name, each in pcall: an error is reported and the rest run. lua/ is prepended to package.path, so lua/<mod>/init.lua loads with require() even under -u. Headless: 10-first.lua requires a module, 20-broken.lua errors and is reported, 30-second.lua still runs. New docs/kalam/zero.md §6, which §3 now points to for session autoload.
- 2026-11-03 17:47 agent:claude addressed in a03a8f1: Follow-up found by the 0.8-0.10 runs: reporting the broken file while init.lua was still being sourced made Neovim prefix 'Error detected while processing …/init.lua:', which points at zero. The report is now scheduled for after startup; all versions pass (117 checks on 0.8/0.9, 134 on 0.10-0.12).
- 2026-11-03 18:07 ank resolved

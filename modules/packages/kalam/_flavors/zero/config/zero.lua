-- kalam-zero: built-in fallbacks for kalam's plugin shortcuts, and the
-- conveniences that matter on a machine reached over ssh (ADR-0016).
-- Runs on Neovim 0.8+; anything newer is behind `has()`. Never errors at
-- startup: a missing feature means a missing shortcut, nothing more.

local Z = {}
_G.KalamZero = Z

local function has(v) return vim.fn.has("nvim-" .. v) == 1 end
local function exe(bin) return vim.fn.executable(bin) == 1 end
local function map(mode, lhs, rhs, desc, opts)
  opts = vim.tbl_extend("force", { silent = true, desc = desc }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end
local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
end
local function notify(msg, level) vim.notify("kalam-zero: " .. msg, level or vim.log.levels.INFO) end

Z.has_rg, Z.has_git = exe("rg"), exe("git")

---------------------------------------------------------------- environment

-- Colors: truecolor only when the terminal says so; habamax ships with
-- 0.8/0.9, whose default scheme is hard to read. 0.10's default is fine.
if vim.env.COLORTERM == "truecolor" or vim.env.COLORTERM == "24bit" then
  vim.o.termguicolors = true
end
if not has("0.10") then pcall(vim.cmd, "colorscheme habamax") end

-- Undo history and sessions need a writable state dir; on a read-only or
-- tmpfs-less home, go without rather than erroring on every write.
do
  local dir = vim.fn.stdpath("state") .. "/undo"
  pcall(vim.fn.mkdir, dir, "p")
  if vim.fn.filewritable(dir) == 2 then vim.o.undodir = dir else vim.o.undofile = false end
end

-- grep: base sets `rg --vimgrep`; without rg, recursive grep from cwd.
if not Z.has_rg then
  vim.o.grepprg = "grep -rnH --exclude-dir=.git $* ."
  vim.o.grepformat = "%f:%l:%m"
end

-- :find searches below cwd. 0.11+ gets a fuzzy file source (rg, git or
-- glob), so `:find foo<Tab>` behaves like a picker.
vim.opt.path = { ".", "**" }
vim.opt.wildignore:append({ "*/.git/*", "*/node_modules/*", "*/.direnv/*", "*/result/*" })
pcall(function() vim.opt.wildoptions:append("fuzzy") end) -- 0.9+

Z.find_source = "files"
local files_cache
local function list_files()
  if files_cache then return files_cache end
  local cmd
  if Z.find_source == "git" and Z.has_git then
    cmd = { "git", "ls-files", "--cached", "--others", "--exclude-standard" }
  elseif Z.has_rg then
    cmd = { "rg", "--files", "--hidden", "-g", "!.git" }
  end
  files_cache = cmd and vim.fn.systemlist(cmd) or vim.fn.glob("**/*", false, true)
  return files_cache
end
function Z.findfunc(arg, _)
  local files = list_files()
  if arg == "" then return files end
  return vim.fn.matchfuzzy(files, arg)
end
if has("0.11") then
  vim.o.findfunc = "v:lua.KalamZero.findfunc"
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = vim.api.nvim_create_augroup("kalam_zero_find", { clear = true }),
    callback = function() files_cache = nil; Z.find_source = "files" end,
  })
end

-- Clipboard over ssh: OSC 52 copies into the local terminal's clipboard.
-- Only when there is no real provider (no xclip/pbcopy/wl-copy): the
-- usual case on a remote box. Paste returns the unnamed register, since
-- few terminals answer OSC 52 paste requests.
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
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
end
local function no_clipboard_tool()
  for _, t in ipairs({ "pbcopy", "wl-copy", "xclip", "xsel", "win32yank.exe", "termux-clipboard-set" }) do
    if exe(t) then return false end
  end
  return true
end
if no_clipboard_tool() then
  local function paste() return { vim.fn.split(vim.fn.getreg('"'), "\n"), vim.fn.getregtype('"') } end
  vim.g.clipboard = {
    name = "kalam-zero OSC 52",
    copy = { ["+"] = Z.osc52_copy, ["*"] = Z.osc52_copy },
    paste = { ["+"] = paste, ["*"] = paste },
  }
end

---------------------------------------------------------------- statusline

local modes = {
  n = "NORMAL", i = "INSERT", v = "VISUAL", V = "V-LINE", ["\22"] = "V-BLOCK",
  c = "COMMAND", R = "REPLACE", t = "TERMINAL", s = "SELECT", S = "S-LINE",
}
function Z.statusline()
  local m = modes[vim.api.nvim_get_mode().mode:sub(1, 1)] or vim.api.nvim_get_mode().mode
  local diag = ""
  local counts = { E = 0, W = 0 }
  for _, d in ipairs(vim.diagnostic.get(0)) do
    if d.severity == vim.diagnostic.severity.ERROR then counts.E = counts.E + 1
    elseif d.severity == vim.diagnostic.severity.WARN then counts.W = counts.W + 1 end
  end
  if counts.E > 0 then diag = diag .. " E" .. counts.E end
  if counts.W > 0 then diag = diag .. " W" .. counts.W end
  local session = vim.v.this_session ~= "" and " [session]" or ""
  return " " .. m .. " │ %f%m%r%h" .. session .. "%=" .. diag .. "  %y  %l:%c  %p%% "
end
vim.o.statusline = "%!v:lua.KalamZero.statusline()"
vim.o.laststatus = 2

---------------------------------------------------------------- autocmds

local aug = vim.api.nvim_create_augroup("kalam_zero", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = aug,
  callback = function()
    local hl = vim.hl or vim.highlight -- vim.hl is 0.11+
    pcall(hl.on_yank, { timeout = 150 })
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = aug,
  callback = function()
    local row, col = unpack(vim.api.nvim_buf_get_mark(0, '"'))
    if row > 0 and row <= vim.api.nvim_buf_line_count(0)
      and vim.bo.filetype ~= "commit" and vim.bo.filetype ~= "gitrebase" then
      pcall(vim.api.nvim_win_set_cursor, 0, { row, col })
    end
  end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  group = aug,
  callback = function()
    if vim.bo.binary or vim.bo.filetype == "diff" then return end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

---------------------------------------------------------------- sessions
-- Same file as kalam's mini.sessions setup: `.nvim.session` in cwd. A
-- session file is Vimscript, and a machine you ssh into may hold someone
-- else's folders, so loading is manual (<leader>ql) by default. With
-- `vim.g.kalam_zero_session_autoload = true` (e.g. in lua/*.lua next to
-- init.lua), a bare `nvim` loads the folder's session, but only one you
-- own that zero wrote (its first line is the marker below). A loaded
-- session is written back on exit.

Z.session_file = ".nvim.session"
Z.session_marker = '" kalam-zero session'
local uv = vim.uv or vim.loop

local function session_write(path)
  vim.cmd("mksession! " .. vim.fn.fnameescape(path))
  local lines = vim.fn.readfile(path)
  if lines[1] ~= Z.session_marker then
    table.insert(lines, 1, Z.session_marker)
    vim.fn.writefile(lines, path)
  end
end

-- Owned by the current user (where uids exist) and written by zero.
function Z.session_trusted(path)
  if vim.fn.filereadable(path) == 0 then return false end
  if uv.getuid then
    local st = uv.fs_stat(path)
    if not st or st.uid ~= uv.getuid() then return false end
  end
  return vim.fn.readfile(path, "", 1)[1] == Z.session_marker
end

function Z.session_save()
  session_write(Z.session_file)
  notify("session saved to " .. Z.session_file)
end
function Z.session_load()
  if vim.fn.filereadable(Z.session_file) == 0 then return notify("no " .. Z.session_file .. " here", vim.log.levels.WARN) end
  vim.cmd("silent! %bwipeout")
  vim.cmd("silent source " .. vim.fn.fnameescape(Z.session_file))
end
function Z.session_delete()
  if vim.fn.delete(Z.session_file) == 0 then vim.v.this_session = ""; notify("session deleted") end
end
vim.api.nvim_create_autocmd("VimEnter", {
  group = aug,
  nested = true,
  callback = function()
    if vim.g.kalam_zero_session_autoload and vim.fn.argc() == 0 and Z.session_trusted(Z.session_file) then
      Z.session_load()
    end
  end,
})
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = aug,
  callback = function()
    if vim.v.this_session ~= "" and vim.fn.filereadable(vim.v.this_session) == 1 then
      session_write(vim.v.this_session)
    end
  end,
})

---------------------------------------------------------------- pickers

function Z.find_files(source)
  Z.find_source = source or "files"
  feed(":find ")
end

local function select(items, prompt, format, on_choice)
  if #items == 0 then return notify("nothing to choose from") end
  vim.ui.select(items, { prompt = prompt, format_item = format }, function(item)
    if item then on_choice(item) end
  end)
end

function Z.buffers()
  -- listed buffers, minus the empty [No Name] a bare `nvim` starts with
  local bufs = vim.tbl_filter(function(b)
    return vim.bo[b].buflisted and (vim.api.nvim_buf_get_name(b) ~= "" or vim.bo[b].modified)
  end, vim.api.nvim_list_bufs())
  select(bufs, "Buffers", function(b)
    local name = vim.api.nvim_buf_get_name(b)
    return name == "" and ("[No Name] " .. b) or vim.fn.fnamemodify(name, ":~:.")
  end, function(b) vim.api.nvim_set_current_buf(b) end)
end

function Z.recent()
  local files = {}
  for _, f in ipairs(vim.v.oldfiles) do
    if #files >= 50 then break end
    if vim.fn.filereadable(f) == 1 then table.insert(files, f) end
  end
  select(files, "Recent files", function(f) return vim.fn.fnamemodify(f, ":~:.") end,
    function(f) vim.cmd("edit " .. vim.fn.fnameescape(f)) end)
end

-- which-key's stand-in: every mapping with a description, in a scratch split.
function Z.keymaps()
  local lines = {}
  for _, mode in ipairs({ "n", "v", "t" }) do
    local maps = vim.api.nvim_get_keymap(mode)
    vim.list_extend(maps, vim.api.nvim_buf_get_keymap(0, mode))
    for _, m in ipairs(maps) do
      if m.desc and m.desc ~= "" then
        local lhs = m.lhs:gsub("^" .. vim.pesc(vim.g.mapleader or "\\"), "<leader>"):gsub(" ", "<space>")
        table.insert(lines, string.format("%s  %-14s %s", mode, lhs, m.desc))
      end
    end
  end
  table.sort(lines)
  vim.cmd("botright new")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.buftype, vim.bo.bufhidden, vim.bo.swapfile, vim.bo.modifiable = "nofile", "wipe", false, false
  vim.api.nvim_buf_set_name(0, "kalam-zero keymaps")
  map("n", "q", "<cmd>close<cr>", "close", { buffer = 0 })
end

function Z.grep(query)
  local function run(q)
    if not q or q == "" then return end
    vim.cmd("silent grep! " .. vim.fn.shellescape(q))
    vim.cmd("botright copen")
  end
  if query then return run(query) end
  vim.ui.input({ prompt = "grep: " }, run)
end

---------------------------------------------------------------- buffers, files, terminal

function Z.buf_delete(force)
  local cur = vim.api.nvim_get_current_buf()
  if not force and vim.bo[cur].modified then return notify("buffer has unsaved changes", vim.log.levels.WARN) end
  vim.cmd("silent! bprevious")
  if vim.api.nvim_get_current_buf() == cur then vim.cmd("enew") end
  pcall(vim.api.nvim_buf_delete, cur, { force = force })
end

function Z.buf_only()
  local cur = vim.api.nvim_get_current_buf()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b ~= cur and vim.bo[b].buflisted and not vim.bo[b].modified then pcall(vim.api.nvim_buf_delete, b, {}) end
  end
end

function Z.rename_file()
  local old = vim.api.nvim_buf_get_name(0)
  if old == "" then return notify("buffer has no file", vim.log.levels.WARN) end
  vim.ui.input({ prompt = "rename to: ", default = old, completion = "file" }, function(new)
    if not new or new == "" or new == old then return end
    vim.cmd("saveas " .. vim.fn.fnameescape(new))
    vim.fn.delete(old)
    vim.cmd("silent! bwipeout " .. vim.fn.bufnr(old))
  end)
end

function Z.scratch()
  vim.cmd("enew")
  vim.bo.buftype, vim.bo.bufhidden, vim.bo.swapfile = "nofile", "hide", false
end

local term = { buf = nil, win = nil }
function Z.terminal()
  if term.win and vim.api.nvim_win_is_valid(term.win) then
    vim.api.nvim_win_close(term.win, true)
    term.win = nil
    return
  end
  vim.cmd("botright 12split")
  term.win = vim.api.nvim_get_current_win()
  if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
    vim.api.nvim_win_set_buf(term.win, term.buf)
  else
    vim.cmd("terminal")
    term.buf = vim.api.nvim_get_current_buf()
    vim.bo[term.buf].buflisted = false
  end
  vim.cmd("startinsert")
end

---------------------------------------------------------------- diagnostics, LSP

function Z.diag_jump(count)
  if vim.diagnostic.jump then return vim.diagnostic.jump({ count = count, float = true }) end -- 0.11+
  if count > 0 then vim.diagnostic.goto_next() else vim.diagnostic.goto_prev() end
end

function Z.diag_toggle()
  if vim.diagnostic.is_enabled then -- 0.10+
    vim.diagnostic.enable(not vim.diagnostic.is_enabled())
  else
    Z._diag_off = not Z._diag_off
    if Z._diag_off then vim.diagnostic.disable() else vim.diagnostic.enable() end
  end
end

function Z.format()
  local clients = (vim.lsp.get_clients or vim.lsp.get_active_clients)({ bufnr = 0 })
  if #clients > 0 then return vim.lsp.buf.format({ async = false }) end
  local view = vim.fn.winsaveview()
  vim.cmd("silent normal! gg=G")
  vim.fn.winrestview(view)
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = aug,
  callback = function(ev)
    local o = { buffer = ev.buf }
    map("n", "gd", vim.lsp.buf.definition, "go to definition", o)
    map("n", "gD", vim.lsp.buf.declaration, "go to declaration", o)
    map("n", "gy", vim.lsp.buf.type_definition, "go to type definition", o)
    map("n", "gr", vim.lsp.buf.references, "references", o)
    map("n", "K", vim.lsp.buf.hover, "hover docs", o)
    map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "code action", o)
    map("n", "<leader>cr", vim.lsp.buf.rename, "rename symbol", o)
    map("n", "<leader>ss", vim.lsp.buf.document_symbol, "lsp symbols", o)
    map("n", "<leader>sS", vim.lsp.buf.workspace_symbol, "lsp workspace symbols", o)
    map("n", "<leader>xs", vim.lsp.buf.document_symbol, "symbols outline", o)
    map("n", "<leader>xl", vim.lsp.buf.references, "lsp definitions / references", o)
  end,
})

---------------------------------------------------------------- git (only with git)

function Z.git_blame_line()
  local file = vim.fn.expand("%:p")
  local line = vim.fn.line(".")
  local out = vim.fn.systemlist({ "git", "-C", vim.fn.expand("%:p:h"), "blame", "-L", line .. "," .. line, "--", file })
  notify(vim.v.shell_error == 0 and out[1] or "not tracked by git")
end

-- Diff the buffer against its staged (index) version, side by side.
function Z.git_diff()
  local rel = vim.fn.systemlist({ "git", "-C", vim.fn.expand("%:p:h"), "ls-files", "--full-name", "--", vim.fn.expand("%:p") })[1]
  if vim.v.shell_error ~= 0 or not rel or rel == "" then return notify("not tracked by git", vim.log.levels.WARN) end
  local ft = vim.bo.filetype
  local index = vim.fn.systemlist({ "git", "-C", vim.fn.expand("%:p:h"), "show", ":" .. rel })
  vim.cmd("diffthis")
  vim.cmd("leftabove vnew")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, index)
  vim.bo.buftype, vim.bo.bufhidden, vim.bo.modifiable, vim.bo.filetype = "nofile", "wipe", false, ft
  vim.api.nvim_buf_set_name(0, "index:" .. rel)
  vim.cmd("diffthis")
  vim.cmd("wincmd p")
end

function Z.diff_off()
  vim.cmd("diffoff!")
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):match("index:") then vim.api.nvim_win_close(w, true) end
  end
end

---------------------------------------------------------------- mini.nvim (0.10+)
-- Inlined into the released init.lua with base's settings (ADR-0018):
-- the editing set, mini.pick for the pickers and mini.clue for
-- which-key's job. On 0.8/0.9 none of this runs and the built-in
-- fallbacks above stay in charge.

Z.mini = {}
if has("0.10") then
  local function setup(name, opts)
    local good, mod = pcall(require, "mini." .. name)
    if good then
      local done = pcall(mod.setup, opts or {})
      Z.mini[name] = done or nil
    end
  end
  setup("pairs")
  setup("move")
  setup("bracketed")
  setup("splitjoin")
  -- base moves surround from s* to gs* (leap owns s/S there)
  setup("surround", {
    mappings = {
      add = "gsa", delete = "gsd", find = "gsf", find_left = "gsF",
      highlight = "gsh", replace = "gsr", update_n_lines = "gsn",
    },
  })
  setup("pick")
  if Z.mini.pick then vim.ui.select = MiniPick.ui_select end

  local good, clue = pcall(require, "mini.clue")
  if good then
    local groups = {
      b = "buffer", c = "code", f = "find/file", g = "git", gh = "hunks", gd = "diff",
      q = "quit/session", s = "search", t = "terminal", u = "toggles", w = "window", x = "diagnostics",
    }
    local clues = {}
    for k, desc in pairs(groups) do
      table.insert(clues, { mode = "n", keys = "<Leader>" .. k, desc = "+" .. desc })
    end
    table.insert(clues, { mode = "n", keys = "gs", desc = "+surround" })
    vim.list_extend(clues, {
      clue.gen_clues.builtin_completion(), clue.gen_clues.g(), clue.gen_clues.marks(),
      clue.gen_clues.registers(), clue.gen_clues.windows(), clue.gen_clues.z(),
    })
    local triggers = {}
    for _, t in ipairs({
      { "n", "<Leader>" }, { "x", "<Leader>" }, { "n", "g" }, { "x", "g" }, { "n", "'" },
      { "n", "`" }, { "n", '"' }, { "x", '"' }, { "i", "<C-r>" }, { "c", "<C-r>" },
      { "n", "<C-w>" }, { "n", "z" }, { "x", "z" }, { "n", "[" }, { "n", "]" },
    }) do
      table.insert(triggers, { mode = t[1], keys = t[2] })
    end
    Z.mini.clue = pcall(clue.setup, { triggers = triggers, clues = clues, window = { delay = 300 } }) or nil
  end
end

-- Picker shortcuts: mini.pick when loaded, the built-in versions otherwise.
local P = Z.mini.pick and MiniPick.builtin
local can_grep = Z.has_rg or Z.has_git -- mini.pick greps with rg or git only
local function recent_files()
  local files = {}
  for _, f in ipairs(vim.v.oldfiles) do
    if vim.fn.filereadable(f) == 1 then table.insert(files, vim.fn.fnamemodify(f, ":~:.")) end
  end
  return files
end
Z.pickers = {
  files = function() if P then P.files() else Z.find_files("files") end end,
  git_files = function()
    if P and Z.has_git then P.files({ tool = "git" }) else Z.find_files("git") end
  end,
  buffers = function() if P then P.buffers() else Z.buffers() end end,
  recent = function()
    if P then MiniPick.start({ source = { items = recent_files(), name = "Recent files" } }) else Z.recent() end
  end,
  help = function() if P then P.help() else feed(":help ") end end,
  grep = function() if P and can_grep then P.grep_live() else Z.grep() end end,
  grep_word = function()
    local word = vim.fn.expand("<cword>")
    if P and can_grep then P.grep({ pattern = word }) else Z.grep(word) end
  end,
}

---------------------------------------------------------------- keymaps
-- Same keys as kalam; base's plain keymaps.nix (save, clipboard, esc) is
-- already loaded above this file.

-- find
map("n", "<leader>ff", Z.pickers.files, "find file")
map("n", "<leader>fg", Z.pickers.git_files, "find git file")
map("n", "<leader>fb", Z.pickers.buffers, "buffers")
map("n", "<leader>,", Z.pickers.buffers, "buffers")
map("n", "<leader>fr", Z.pickers.recent, "recent files")
map("n", "<leader>fh", Z.pickers.help, "help")
map("n", "<leader>fk", Z.keymaps, "keymaps")
map("n", "<leader>fc", function() feed(":") end, "commands")
map("n", "<leader>:", "q:", "command history")

-- search
map("n", "<leader>/", Z.pickers.grep, "grep")
map("n", "<leader>sg", Z.pickers.grep, "grep workspace")
map("n", "<leader>sw", Z.pickers.grep_word, "word under cursor")
if P then map("n", "<leader>sr", function() P.resume() end, "resume last picker") end
map("n", "<leader>sd", function() vim.diagnostic.setqflist() end, "diagnostics")
map("n", "<leader>sm", "<cmd>marks<cr>", "marks")
map("n", "<leader>sq", "<cmd>botright copen<cr>", "quickfix list")
map("n", "<leader>sj", "<cmd>jumps<cr>", "jumps")

-- explorer: oil.nvim, inlined into the released init.lua (ADR-0017), with
-- base's settings; netrw only if oil can't load.
Z.has_oil, Z.oil = pcall(require, "oil")
if Z.has_oil then
  Z.oil.setup({
    default_file_explorer = true,
    view_options = { show_hidden = true },
    keymaps = { ["<C-p>"] = "actions.preview" },
    float = { padding = 2, max_width = 100, max_height = 30, border = "rounded" },
  })
  map("n", "<leader>o", function() Z.oil.open() end, "oil — files as buffer")
  map("n", "<leader>e", function() Z.oil.toggle_float() end, "explorer (oil float)")
  map("n", "-", function() Z.oil.open() end, "parent directory")
else
  vim.g.netrw_banner = 0
  vim.g.netrw_liststyle = 3
  map("n", "<leader>e", "<cmd>Lexplore 30<cr>", "explorer")
  map("n", "<leader>o", "<cmd>Explore<cr>", "files as buffer")
end

-- buffers
map("n", "<leader>bd", function() Z.buf_delete(false) end, "delete buffer")
map("n", "<leader>bD", function() Z.buf_delete(true) end, "delete buffer (force)")
map("n", "<leader>bo", Z.buf_only, "delete other buffers")
map("n", "<leader>ba", "<cmd>silent! %bdelete<cr>", "delete all buffers")
map("n", "<S-l>", "<cmd>bnext<cr>", "next buffer")
map("n", "<S-h>", "<cmd>bprevious<cr>", "prev buffer")

-- sessions and quitting
map("n", "<leader>qs", Z.session_save, "save session")
map("n", "<leader>ql", Z.session_load, "load session")
map("n", "<leader>qd", Z.session_delete, "delete session")
map("n", "<leader>qq", "<cmd>qa<cr>", "quit all")
map("n", "<leader>qQ", "<cmd>qa!<cr>", "quit all (force)")

-- code and diagnostics (LSP keys are added per buffer on LspAttach)
map("n", "[d", function() Z.diag_jump(-1) end, "prev diagnostic")
map("n", "]d", function() Z.diag_jump(1) end, "next diagnostic")
map("n", "<leader>cd", function() vim.diagnostic.open_float() end, "line diagnostics")
map("n", "<leader>cf", Z.format, "format")
map("n", "<leader>cR", Z.rename_file, "rename file")
map("n", "<leader>xx", function() vim.diagnostic.setqflist() end, "diagnostics (workspace)")
map("n", "<leader>xX", function() vim.diagnostic.setloclist() end, "diagnostics (buffer)")
map("n", "<leader>xL", "<cmd>lopen<cr>", "location list")
map("n", "<leader>xQ", "<cmd>botright copen<cr>", "quickfix list")

-- git
if Z.has_git then
  map("n", "<leader>gb", Z.git_blame_line, "blame line")
  map("n", "<leader>ghd", Z.git_diff, "diff against index")
  map("n", "<leader>gdd", Z.diff_off, "close diff")
end

-- terminal, windows, toggles, misc
map("n", "<leader>tt", Z.terminal, "toggle terminal")
map("t", "<C-\\><C-t>", function() Z.terminal() end, "toggle terminal")
map("n", "<leader>w", "<C-w>", "window", { remap = true })
map("n", "<leader>un", "<cmd>set number!<cr>", "line numbers")
map("n", "<leader>ur", "<cmd>set relativenumber!<cr>", "relative numbers")
map("n", "<leader>uw", "<cmd>set wrap!<cr>", "wrap")
map("n", "<leader>us", "<cmd>set spell!<cr>", "spell")
map("n", "<leader>ud", Z.diag_toggle, "diagnostics")
if has("0.12") then map("n", "<leader>uu", function() vim.cmd("packadd nvim.undotree"); vim.cmd("Undotree") end, "undo tree") end
map("n", "<leader>S", Z.scratch, "scratch buffer")
map("n", "<leader>n", "<cmd>messages<cr>", "message history")

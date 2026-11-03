-- Headless test for kalam-zero's init.lua (ADR-0016). Started as
--   NVIM_APPNAME=kalam nvim --headless -c "luafile headless.lua"
-- from a scratch git repo with `needle.txt` and `src/other.lua`. Writes
-- failures to stderr and exits non-zero on any; prints "kalam-zero: ok N
-- checks" on success. Prompts (vim.ui.select / vim.ui.input) answer
-- themselves with the first item / a scripted reply.

local failures, checks = {}, 0
local function ok(cond, what)
  checks = checks + 1
  if not cond then table.insert(failures, what) end
end
local function try(what, fn)
  local good, err = pcall(fn)
  ok(good, what .. ": " .. tostring(err))
end

local function run()
  local Z = _G.KalamZero
  ok(Z ~= nil, "zero.lua loaded (_G.KalamZero); startup said: " .. vim.v.errmsg .. " " .. vim.fn.execute("messages"))
  if not Z then return end

  -- your own Lua ran in name order, a module loaded, the broken file was
  -- reported, and nothing else stopped
  local msgs = vim.fn.execute("messages")
  local user = vim.g.kalam_zero_user or {}
  ok(user[1] == 42, "lua/10-first.lua ran and required lua/kalamtest: " .. vim.inspect(user))
  ok(user[2] == "second", "lua/30-second.lua ran after the broken one: " .. vim.inspect(user))
  ok(msgs:match("error in [^\n]*20%-broken%.lua"), "the broken file was reported")
  msgs = msgs:gsub("[^\n]*20%-broken%.lua[^\n]*", "")

  -- startup was otherwise silent
  ok(not msgs:match("E%d+:") and not msgs:match("[Ee]rror"), "no startup errors: " .. msgs)
  ok(vim.v.errmsg == "" or vim.v.errmsg:match("20%-broken%.lua"), "v:errmsg empty but for the broken file: " .. vim.v.errmsg)

  -- every zero shortcut, and base's plain ones, are mapped
  local expected = {
    "<leader><space>", "<leader>y", "<leader>p",
    "<leader>ff", "<leader>fg", "<leader>fb", "<leader>,", "<leader>fr", "<leader>fh", "<leader>fk",
    "<leader>fc", "<leader>:", "<leader>/", "<leader>sg", "<leader>sw", "<leader>sd", "<leader>sm",
    "<leader>sq", "<leader>sj", "<leader>e", "<leader>o", "<leader>bd", "<leader>bD", "<leader>bo",
    "<leader>ba", "<S-l>", "<S-h>", "<leader>qs", "<leader>ql", "<leader>qd", "<leader>qq", "<leader>qQ",
    "[d", "]d", "<leader>cd", "<leader>cf", "<leader>cR", "<leader>xx", "<leader>xX", "<leader>xL",
    "<leader>xQ", "<leader>gb", "<leader>ghd", "<leader>gdd", "<leader>tt", "<leader>w", "<leader>un",
    "<leader>ur", "<leader>uw", "<leader>us", "<leader>ud", "<leader>S", "<leader>n", "-",
  }
  for _, lhs in ipairs(expected) do ok(vim.fn.maparg(lhs, "n") ~= "", "mapped: " .. lhs) end

  -- mini.nvim (ADR-0018): set up on 0.10+, absent on 0.8/0.9
  local new = vim.fn.has("nvim-0.10") == 1
  for _, m in ipairs({ "pairs", "move", "bracketed", "splitjoin", "surround", "pick", "clue" }) do
    ok((Z.mini[m] == true) == new, "mini." .. m .. (new and " set up" or " not set up on this version"))
  end
  if new then
    for _, k in ipairs({ { "n", "gsa" }, { "n", "gsd" }, { "n", "gsr" }, { "n", "<M-j>" }, { "n", "]b" }, { "n", "gS" }, { "i", "(" }, { "n", "<leader>sr" } }) do
      ok(vim.fn.maparg(k[2], k[1]) ~= "", "mini mapping " .. k[1] .. " " .. k[2])
    end
    ok(vim.ui.select == MiniPick.ui_select, "vim.ui.select is mini.pick's")
    local d = vim.fn.maparg("]d", "n", false, true)
    ok(d.desc == "next diagnostic", "]d stays zero's diagnostic jump, not bracketed's: " .. tostring(d.desc))
    -- the find/grep shortcuts call mini.pick: stub its builtins and press them
    local called = {}
    for _, b in ipairs({ "files", "buffers", "help", "grep_live", "grep" }) do
      MiniPick.builtin[b] = function() called[b] = true end
    end
    local start = MiniPick.start
    MiniPick.start = function(o) called.start = o.source.name end
    for _, k in ipairs({ "<leader>ff", "<leader>fb", "<leader>fh", "<leader>/", "<leader>sw", "<leader>fr" }) do
      vim.fn.maparg(k, "n", false, true).callback()
    end
    MiniPick.start = start
    ok(called.files and called.buffers and called.help, "pickers use mini.pick")
    ok(called.grep_live and called.grep, "grep uses mini.pick (rg or git present)")
    ok(called.start == "Recent files", "recent files use mini.pick")
    try("surround", function()
      vim.cmd("enew")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "word" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("normal gsaiw)")
      ok(vim.api.nvim_get_current_line() == "(word)", "gsaiw) surrounds: " .. vim.api.nvim_get_current_line())
    end)
    try("splitjoin", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "f(a, b, c)" })
      vim.api.nvim_win_set_cursor(0, { 1, 3 })
      MiniSplitjoin.split()
      ok(vim.api.nvim_buf_line_count(0) == 5, "splitjoin splits the arglist: " .. vim.api.nvim_buf_line_count(0) .. " lines")
      vim.bo.modified = false
    end)
  end

  ok(vim.o.timeoutlen == (new and 300 or 800), "timeoutlen " .. vim.o.timeoutlen .. (new and " (mini.clue)" or ""))

  -- options that differ from base
  ok(vim.o.foldmethod == "indent", "foldmethod indent")
  ok(vim.o.exrc == false, "exrc off")
  ok(vim.o.statusline:match("KalamZero"), "statusline set")

  -- prompts answer themselves
  local reply = nil
  vim.ui.select = function(items, _, cb) cb(items[1]) end
  vim.ui.input = function(_, cb) cb(reply) end

  -- grep (rg or grep, per $KALAM_ZERO_EXPECT_RG)
  try("grep", function()
    Z.grep("needle")
    local qf = vim.fn.getqflist()
    ok(#qf >= 1, "grep found needle (" .. #qf .. " hits, grepprg=" .. vim.o.grepprg .. ")")
    vim.cmd("cclose")
  end)
  ok(Z.has_rg == (os.getenv("KALAM_ZERO_EXPECT_RG") == "1"), "rg detection")
  -- no rg and no grep (a stock Windows): :vimgrep
  try("vimgrep fallback", function()
    local rg, grep = Z.has_rg, Z.has_grep
    Z.has_rg, Z.has_grep = false, false
    Z.grep("needle")
    Z.has_rg, Z.has_grep = rg, grep
    local qf = vim.fn.getqflist()
    ok(#qf >= 1 and vim.fn.bufname(qf[1].bufnr):match("needle%.txt"), "vimgrep found needle (" .. #qf .. " hits)")
    vim.cmd("cclose")
  end)

  -- oil, inlined into init.lua: lists the directory, hides its line IDs,
  -- and creates a file from an edited buffer
  ok(Z.has_oil, "oil loaded from package.preload: " .. tostring(Z.oil))
  if Z.has_oil then
    try("oil", function()
      Z.oil.open(vim.fn.getcwd())
      ok(vim.wait(3000, function() return vim.bo.filetype == "oil" and vim.fn.search("needle.txt", "n") > 0 end),
        "oil lists needle.txt")
      ok(vim.b.current_syntax == "oil", "oil syntax loaded (conceals IDs): " .. tostring(vim.b.current_syntax))
      vim.api.nvim_buf_set_lines(0, -1, -1, false, { "created.txt" })
      Z.oil.save({ confirm = false })
      ok(vim.wait(3000, function() return vim.fn.filereadable("created.txt") == 1 end), "oil created created.txt")
      vim.cmd("enew")
    end)
  end

  -- file source for :find
  try("find source", function()
    Z.find_source = "git"
    local files = Z.findfunc("other", nil)
    ok(vim.tbl_contains(files, "src/other.lua"), "findfunc fuzzy-matches src/other.lua")
  end)

  -- buffers and recent files
  try("buffers", function()
    vim.cmd("edit needle.txt")
    vim.cmd("edit src/other.lua")
    Z.buffers()
    ok(vim.fn.expand("%:t") ~= "", "buffers picked one")
    vim.v.oldfiles = { vim.fn.fnamemodify("needle.txt", ":p") }
    Z.recent()
    ok(vim.fn.expand("%:t") == "needle.txt", "recent opened needle.txt")
  end)

  -- keymap listing (which-key stand-in)
  try("keymaps", function()
    Z.keymaps()
    local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    ok(text:match("find file"), "keymaps list shows descriptions")
    vim.cmd("close")
  end)

  -- sessions: never loaded unasked, and only zero's own when asked
  ok(vim.g.kalam_zero_session_ran == nil and vim.v.this_session == "", "session not autoloaded by default")
  ok(Z.session_trusted(".nvim.session"), "a marked session we own is trusted")
  vim.fn.writefile({ "let g:kalam_zero_session_ran = 1" }, "unmarked.session")
  ok(not Z.session_trusted("unmarked.session"), "an unmarked session is not trusted")
  vim.fn.delete("unmarked.session")
  try("sessions", function()
    Z.session_save()
    ok(vim.fn.readfile(".nvim.session", "", 1)[1] == Z.session_marker, "saved session carries the marker")
    ok(vim.fn.filereadable(".nvim.session") == 1, "session written")
    Z.session_load()
    ok(vim.v.this_session:match("%.nvim%.session$"), "session loaded")
    Z.session_delete()
    ok(vim.fn.filereadable(".nvim.session") == 0, "session deleted")
  end)

  -- OSC 52: the escape sequence carries base64 of the yanked text
  try("osc52", function()
    local sent
    local chansend = vim.fn.chansend
    vim.fn.chansend = function(_, data) sent = data end
    Z.osc52_copy({ "hello", "world" })
    ok(sent and sent:find("aGVsbG8Kd29ybGQ=", 1, true), "osc52 base64: " .. tostring(sent))
    -- the 0.8/0.9 encoder agrees with vim.base64 where both exist
    local sample = "kalam-zero \0\1\255 é\n" .. string.rep("xyz", 100)
    ok(vim.base64 == nil or Z.b64(sample) == vim.base64.encode(sample), "fallback base64 matches vim.base64")
    ok(Z.encode == (vim.base64 and vim.base64.encode or Z.b64), "uses vim.base64 when present")
    -- too large: nothing sent, a warning instead
    sent = nil
    local warned
    local notify_ = vim.notify
    vim.notify = function(msg) warned = msg end
    Z.osc52_copy({ string.rep("a", 80000) })
    vim.notify = notify_
    vim.fn.chansend = chansend
    ok(sent == nil and warned and warned:match("too large for OSC 52"), "oversized copy warns: " .. tostring(warned))
  end)

  -- git: blame and diff against the index
  try("git", function()
    vim.cmd("edit needle.txt")
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { "changed" })
    Z.git_diff()
    ok(#vim.api.nvim_tabpage_list_wins(0) == 2 and vim.wo.diff, "diff split opened")
    Z.diff_off()
    ok(#vim.api.nvim_tabpage_list_wins(0) == 1, "diff split closed")
    vim.cmd("edit!")
    Z.git_blame_line()
  end)

  -- buffers: delete keeps the window, rename moves the file
  try("buffer ops", function()
    vim.cmd("edit src/other.lua")
    local before = #vim.api.nvim_list_wins()
    Z.buf_delete(false)
    ok(#vim.api.nvim_list_wins() == before, "buf_delete keeps window")
    vim.cmd("edit src/other.lua")
    reply = "src/renamed.lua"
    Z.rename_file()
    ok(vim.fn.filereadable("src/renamed.lua") == 1 and vim.fn.filereadable("src/other.lua") == 0, "rename_file")
  end)

  -- the rest just has to run
  try("statusline", function() ok(type(Z.statusline()) == "string", "statusline renders") end)
  try("format", function() vim.cmd("edit needle.txt"); Z.format() end)
  try("diag toggle", function() Z.diag_toggle(); Z.diag_toggle() end)
  try("diag jump", function() Z.diag_jump(1) end)
  try("scratch", function() Z.scratch(); ok(vim.bo.buftype == "nofile", "scratch is nofile") end)
  try("terminal", function()
    Z.terminal()
    ok(vim.bo.buftype == "terminal", "terminal opened")
    vim.cmd("stopinsert")
    Z.terminal()
  end)
  try("buf only", Z.buf_only)
end

local function finish()
  local good, err = pcall(run)
  if not good then table.insert(failures, "test crashed: " .. tostring(err)) end
  if #failures > 0 then
    io.stderr:write("kalam-zero: " .. #failures .. " of " .. checks .. " checks failed\n")
    for _, f in ipairs(failures) do io.stderr:write("  - " .. f .. "\n") end
    vim.cmd("cquit 1")
  end
  io.stdout:write("kalam-zero: ok " .. checks .. " checks (" .. vim.fn.execute("version"):match("NVIM v[%d%.]+") .. ")\n")
  vim.cmd("qall!")
end

if vim.v.vim_did_enter == 1 then finish() else
  vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = function() vim.schedule(finish) end })
end

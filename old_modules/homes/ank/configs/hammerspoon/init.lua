hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall.repos.PaperWM = {
	url = "https://github.com/mogenson/PaperWM.spoon",
	desc = "PaperWM.spoon repository",
	branch = "release",
}

spoon.SpoonInstall:andUse("PaperWM", {
	repo = "PaperWM",
	config = { screen_margin = 16, window_gap = 2 },
	start = true,
})

ActiveSpace = hs.loadSpoon("ActiveSpace")
ActiveSpace:start()

PaperWM = hs.loadSpoon("PaperWM")
PaperWM:bindHotkeys({
	-- switch to a new focused window in tiled grid
	focus_left = { { "alt", "cmd" }, "left" },
	focus_right = { { "alt", "cmd" }, "right" },
	focus_up = { { "alt", "cmd" }, "up" },
	focus_down = { { "alt", "cmd" }, "down" },

	-- switch windows by cycling forward/backward
	-- (forward = down or right, backward = up or left)
	focus_prev = { { "alt", "cmd" }, "k" },
	focus_next = { { "alt", "cmd" }, "j" },

	-- move windows around in tiled grid
	swap_left = { { "alt", "cmd", "shift" }, "left" },
	swap_right = { { "alt", "cmd", "shift" }, "right" },
	swap_up = { { "alt", "cmd", "shift" }, "up" },
	swap_down = { { "alt", "cmd", "shift" }, "down" },

	-- alternative: swap entire columns, rather than
	-- individual windows (to be used instead of
	-- swap_left / swap_right bindings)
	-- swap_column_left = {{"alt", "cmd", "shift"}, "left"},
	-- swap_column_right = {{"alt", "cmd", "shift"}, "right"},

	-- position and resize focused window
	center_window = { { "alt", "cmd" }, "c" },
	full_width = { { "alt", "cmd" }, "f" },
	cycle_width = { { "alt", "cmd" }, "r" },
	reverse_cycle_width = { { "ctrl", "alt", "cmd" }, "r" },
	cycle_height = { { "alt", "cmd", "shift" }, "r" },
	reverse_cycle_height = { { "ctrl", "alt", "cmd", "shift" }, "r" },

	-- increase/decrease width
	increase_width = { { "alt", "cmd" }, "l" },
	decrease_width = { { "alt", "cmd" }, "h" },

	-- move focused window into / out of a column
	slurp_in = { { "alt", "cmd" }, "i" },
	barf_out = { { "alt", "cmd" }, "o" },

	-- move the focused window into / out of the tiling layer
	toggle_floating = { { "alt", "cmd", "shift" }, "escape" },

	-- focus the first / second / etc window in the current space
	focus_window_1 = { { "cmd", "shift" }, "1" },
	focus_window_2 = { { "cmd", "shift" }, "2" },
	focus_window_3 = { { "cmd", "shift" }, "3" },
	focus_window_4 = { { "cmd", "shift" }, "4" },
	focus_window_5 = { { "cmd", "shift" }, "5" },
	focus_window_6 = { { "cmd", "shift" }, "6" },
	focus_window_7 = { { "cmd", "shift" }, "7" },
	focus_window_8 = { { "cmd", "shift" }, "8" },
	focus_window_9 = { { "cmd", "shift" }, "9" },

	-- switch to a new Mission Control space
	switch_space_l = { { "alt", "cmd" }, "," },
	switch_space_r = { { "alt", "cmd" }, "." },
	switch_space_1 = { { "alt", "cmd" }, "1" },
	switch_space_2 = { { "alt", "cmd" }, "2" },
	switch_space_3 = { { "alt", "cmd" }, "3" },
	switch_space_4 = { { "alt", "cmd" }, "4" },
	switch_space_5 = { { "alt", "cmd" }, "5" },
	switch_space_6 = { { "alt", "cmd" }, "6" },
	switch_space_7 = { { "alt", "cmd" }, "7" },
	switch_space_8 = { { "alt", "cmd" }, "8" },
	switch_space_9 = { { "alt", "cmd" }, "9" },

	-- move focused window to a new space and tile
	move_window_1 = { { "alt", "cmd", "shift" }, "1" },
	move_window_2 = { { "alt", "cmd", "shift" }, "2" },
	move_window_3 = { { "alt", "cmd", "shift" }, "3" },
	move_window_4 = { { "alt", "cmd", "shift" }, "4" },
	move_window_5 = { { "alt", "cmd", "shift" }, "5" },
	move_window_6 = { { "alt", "cmd", "shift" }, "6" },
	move_window_7 = { { "alt", "cmd", "shift" }, "7" },
	move_window_8 = { { "alt", "cmd", "shift" }, "8" },
	move_window_9 = { { "alt", "cmd", "shift" }, "9" },
})

-- use ⌘ Enter as hyper key to enter modal layer, press Escape to exit
local modal = hs.hotkey.modal.new({ "cmd" }, "return")

local actions = PaperWM.actions.actions()
modal:bind({}, "h", nil, actions.focus_left)
modal:bind({}, "j", nil, actions.focus_down)
modal:bind({}, "k", nil, actions.focus_up)
modal:bind({}, "l", nil, actions.focus_right)
modal:bind({}, "escape", nil, function()
	modal:exit()
end)

-- set to a table of modifier keys to enable window dragging, default is nil
-- PaperWM.drag_window = { "alt", "cmd" }

-- set to a table of modifier keys to enable window lifting, default is nil
-- PaperWM.lift_window = { "alt", "cmd", "shift" }

-- Remove janky transitions
hs.window.animationDuration = 0

-- number of fingers to detect a horizontal swipe, set to 0 to disable (the default)
PaperWM.swipe_fingers = 0

-- increase this number to make windows move farther when swiping
PaperWM.swipe_gain = 1.0

PaperWM:start()

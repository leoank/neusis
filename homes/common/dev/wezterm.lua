local wezterm = require("wezterm")
local config = {}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.default_cursor_style = "BlinkingBlock"

-- title bar
config.window_decorations = "RESIZE"

if wezterm.target_triple == "x86_64-pc-windows-msvc" then
	-- wezterm on windows config
	config.default_domain = "WSL:nix"
	config.launch_menu = {
		{
			label = "Powershell",
			domain = { DomainName = "local" },
			args = { "C:/Program Files/PowerShell/7/pwsh.exe", "-verb", "runas" },
		},
	}
end

-- tab bar
local bar = wezterm.plugin.require("https://github.com/adriankarlen/bar.wezterm")
bar.apply_to_config(config, {
	modules = {
		pane = {
			enabled = false,
		},
		workspace = {
			enabled = false,
		},
		cwd = {
			enabled = false,
		},
	},
})

return config

-- Hyprland config for the MU/TH/UR shell: the same keybinds, autostart
-- and look rules as dotfiles/labwc, in Hyprland's Lua config
-- (https://wiki.hypr.land/Configuring/). Colors come from colors.lua,
-- generated next to this file by ThemeStore.qml on every preset change,
-- the way labwc's themerc-override is.

------------------
---- MONITORS ----
------------------

-- kanshi (autostarted below) applies per-output profiles on top of this.
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-------------------
---- AUTOSTART ----
-------------------

-- Same set as dotfiles/labwc/autostart. The wallpaper is swaybg: a solid
-- color until the shell (ThemeStore.qml) takes it over with the preset's
-- background or the chosen image.
hl.on("hyprland.start", function()
	hl.exec_cmd("swaybg -c '#113344'")
	hl.exec_cmd("kanshi")
	hl.exec_cmd("mako")
	-- Lock after 5 minutes; turn the display off after another 5.
	hl.exec_cmd(
		"swayidle -w timeout 300 'swaylock -f -c 000000' timeout 600 'wlopm --off \\*' resume 'wlopm --on \\*' before-sleep 'swaylock -f -c 000000'"
	)
	hl.exec_cmd("quickshell -c muthur")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- Mirrors dotfiles/labwc/environment: alacritty for anything that honors
-- $TERMINAL, and yazi's "edit" opener stays in the terminal with nvim.
hl.env("TERMINAL", "alacritty")
hl.env("EDITOR", "nvim")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- The shell's rules: 1px sharp borders, no rounding, no blur, no shadow.
-- colors.lua is generated; fall back to plain grey when it isn't there
-- yet (first start before the shell has run).
local ok, colors = pcall(require, "colors")
if not ok then
	colors = { fg = "rgb(aaaaaa)", dim = "rgb(555555)" }
end

hl.config({
	general = {
		-- One grid unit (6px) between windows and around the edge.
		gaps_in = 3,
		gaps_out = 6,
		border_size = 1,
		col = {
			active_border = colors.fg,
			inactive_border = colors.dim,
		},
		resize_on_border = true,
		allow_tearing = false,
		layout = "dwindle",
	},

	decoration = {
		rounding = 0,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = { enabled = false },
		blur = { enabled = false },
	},

	animations = {
		enabled = false,
	},

	dwindle = {
		preserve_split = true,
	},

	misc = {
		-- swaybg draws the background; no logo, splash or mascot.
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		force_default_wallpaper = 0,
		-- A bell or activation request from an unfocused window marks it
		-- urgent (the bar highlights its workspace) instead of stealing focus.
		focus_on_activate = false,
	},

	input = {
		kb_layout = "us",
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = {
			natural_scroll = false,
		},
	},
})

---------------------
---- KEYBINDINGS ----
---------------------

-- The labwc set from dotfiles/labwc/rc.xml, plus what a tiler needs.
local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("alacritty"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("fuzzel"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("alacritty -e yazi"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind("ALT + Tab", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Workspaces: Super+N to go, Super+Shift+N to send the window along.
-- Four, like the labwc config; Hyprland creates them on demand.
for i = 1, 4 do
	hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume keys (pipewire/wireplumber); brightness is in the shell's [SYS] > DISPLAY.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

------------------------
---- WINDOW RULES ----
------------------------

hl.window_rule({
	-- Ignore maximize requests from all apps.
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	-- Fix some dragging issues with XWayland
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

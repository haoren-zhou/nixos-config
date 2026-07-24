local function bind(keys, dispatcher, options)
	hl.bind(keys, dispatcher, options)
end

local function exec(keys, command, options)
	bind(keys, hl.dsp.exec_cmd(command), options)
end

local repeating = { repeating = true }

for _, entry in ipairs({
	{ "right", 30, 0 },
	{ "left", -30, 0 },
	{ "up", 0, -30 },
	{ "down", 0, 30 },
	{ "l", 30, 0 },
	{ "h", -30, 0 },
	{ "k", 0, -30 },
	{ "j", 0, 30 },
}) do
	bind(
		main_mod .. " + ALT + " .. entry[1],
		hl.dsp.window.resize({ x = entry[2], y = entry[3], relative = true }),
		repeating
	)
end

exec("XF86MonBrightnessDown", swayosd .. " --brightness -2", repeating)
exec("XF86MonBrightnessUp", swayosd .. " --brightness +2", repeating)
exec("XF86AudioLowerVolume", swayosd .. " --output-volume -2", repeating)
exec("XF86AudioRaiseVolume", swayosd .. " --output-volume +2", repeating)

exec(main_mod .. " + F9", hyprsunset .. " --temperature 3500")
exec(main_mod .. " + F10", "pkill hyprsunset")
bind(main_mod .. " + Q", hl.dsp.window.close())
bind("ALT + F4", hl.dsp.window.close())
bind(main_mod .. " + Delete", hl.dsp.exit())
bind(main_mod .. " + W", hl.dsp.window.float({ action = "toggle" }))
bind(main_mod .. " + SHIFT + G", hl.dsp.group.toggle())
bind("ALT + Return", hl.dsp.window.fullscreen())
exec("CTRL + ALT + L", "hyprlock")
exec(main_mod .. " + BackSpace", "pkill -x wlogout || wlogout -b 4")
exec(main_mod .. " + Escape", "pkill -x wlogout || wlogout -b 4")
exec("CTRL + Escape", "pkill waybar || waybar")

exec(main_mod .. " + Return", terminal)
exec(main_mod .. " + T", terminal)
exec(main_mod .. " + F", "thunar")
exec(main_mod .. " + C", editor)
exec(main_mod .. " + B", browser)
exec("CTRL + ALT + Delete", terminal .. " -e btop")
exec(main_mod .. " + CTRL + C", "hyprpicker --autocopy --format=hex")

exec(main_mod .. " + A", "pkill -x rofi || " .. scripts .. "/rofi.sh drun")
exec("CTRL + Space", "pkill -x rofi || " .. scripts .. "/rofi.sh drun")
exec(main_mod .. " + Space", "pkill -x rofi || " .. scripts .. "/rofi.sh drun")
exec(main_mod .. " + E", "pkill -x rofi || " .. scripts .. "/rofi.sh emoji")
exec(main_mod .. " + CTRL + Space", "fcitx5-remote -t")
exec(main_mod .. " + I", "fcitx5-remote -t")
exec(main_mod .. " + N", "swaync-client -t -sw")
exec(main_mod .. " + V", scripts .. "/ClipManager.sh")
exec(main_mod .. " + M", "pkill -x rofi || " .. scripts .. "/rofimusic.sh")

exec(main_mod .. " + SHIFT + S", scripts .. "/screenshot.sh s")
exec(main_mod .. " + CTRL + S", scripts .. "/screenshot.sh sf")
exec(main_mod .. " + CTRL + P", scripts .. "/screenshot.sh m")

exec("XF86Sleep", "systemctl suspend")
exec("XF86AudioMicMute", "pamixer --default-source -t")
exec("XF86AudioMute", "pamixer -t")
exec("XF86AudioPlay", "playerctl play-pause")
exec("XF86AudioPause", "playerctl play-pause")
exec("XF86AudioNext", "playerctl next")
exec("XF86AudioPrev", "playerctl previous")

bind("ALT + Tab", function()
	hl.dispatch(hl.dsp.window.cycle_next())
	hl.dispatch(hl.dsp.window.bring_to_top())
end)

for _, entry in ipairs({
	{ "right", "r+1" },
	{ "left", "r-1" },
	{ "h", "r-1" },
	{ "l", "r+1" },
	{ "down", "empty" },
	{ "j", "empty" },
}) do
	bind(main_mod .. " + CTRL + " .. entry[1], hl.dsp.focus({ workspace = entry[2] }))
end

for _, entry in ipairs({
	{ "left", "left" },
	{ "right", "right" },
	{ "up", "up" },
	{ "down", "down" },
	{ "h", "left" },
	{ "l", "right" },
	{ "k", "up" },
	{ "j", "down" },
}) do
	bind(main_mod .. " + " .. entry[1], hl.dsp.focus({ direction = entry[2] }))
end

bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

bind(main_mod .. " + CTRL + ALT + right", hl.dsp.window.move({ workspace = "r+1" }))
bind(main_mod .. " + CTRL + ALT + left", hl.dsp.window.move({ workspace = "r-1" }))

for _, entry in ipairs({
	{ "left", "left" },
	{ "right", "right" },
	{ "up", "up" },
	{ "down", "down" },
	{ "H", "left" },
	{ "L", "right" },
	{ "K", "up" },
	{ "J", "down" },
}) do
	bind(main_mod .. " + SHIFT + " .. entry[1], hl.dsp.window.move({ direction = entry[2] }))
end

for workspace = 1, 10 do
	local key = workspace % 10
	bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
	bind(main_mod .. " + CTRL + " .. key, hl.dsp.window.move({ workspace = workspace }))
	bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace, follow = false }))
end

bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

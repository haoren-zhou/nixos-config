-- Hyprland 0.55+ Lua configuration. `scripts` and `hyprsunset` are supplied
-- by Home Manager so they always resolve to immutable Nix store paths.

local main_mod = "SUPER"
local terminal = "kitty"
local editor = "code --disable-gpu"
local browser = "zen"

for name, value in pairs({
	XDG_CURRENT_DESKTOP = "Hyprland",
	XDG_SESSION_DESKTOP = "Hyprland",
	XDG_SESSION_TYPE = "wayland",
	GDK_BACKEND = "wayland,x11,*",
	NIXOS_OZONE_WL = "1",
	ELECTRON_OZONE_PLATFORM_HINT = "auto",
	MOZ_ENABLE_WAYLAND = "1",
	OZONE_PLATFORM = "wayland",
	EGL_PLATFORM = "wayland",
	CLUTTER_BACKEND = "wayland",
	SDL_VIDEODRIVER = "wayland",
	QT_QPA_PLATFORM = "wayland;xcb",
	QT_WAYLAND_DISABLE_WINDOWDECORATION = "1",
	QT_QPA_PLATFORMTHEME = "qt6ct",
	QT_AUTO_SCREEN_SCALE_FACTOR = "1",
	WLR_RENDERER_ALLOW_SOFTWARE = "1",
	NIXPKGS_ALLOW_UNFREE = "1",
}) do
	hl.env(name, value)
end

hl.monitor({ output = "", mode = "highrr", position = "auto", scale = "auto" })

hl.config({
	binds = { workspace_back_and_forth = true },
	input = {
		kb_layout = "us,cn",
		kb_variant = "",
		repeat_delay = 400,
		repeat_rate = 30,
		follow_mouse = 1,
		sensitivity = 0,
		force_no_accel = true,
		touchpad = { natural_scroll = true },
		tablet = { output = "current" },
	},
	general = {
		gaps_in = 4,
		gaps_out = 9,
		border_size = 2,
		col = {
			active_border = { colors = { "rgba(6e92dbff)", "rgba(7878ffff)" }, angle = 45 },
			inactive_border = { colors = { "rgba(ccd3fecc)", "rgba(8d90a3cc)" }, angle = 45 },
		},
		resize_on_border = true,
		layout = "dwindle",
	},
	decoration = {
		shadow = { enabled = false },
		rounding = 10,
		dim_special = 0.3,
		blur = {
			enabled = true,
			special = true,
			size = 6,
			passes = 2,
			new_optimizations = true,
			ignore_opacity = true,
			xray = false,
		},
	},
	group = {
		col = {
			border_active = { colors = { "rgba(6e92dbff)", "rgba(7878ffff)" }, angle = 45 },
			border_inactive = { colors = { "rgba(ccd3fecc)", "rgba(8d90a3cc)" }, angle = 45 },
			border_locked_active = { colors = { "rgba(6e92dbff)", "rgba(7878ffff)" }, angle = 45 },
			border_locked_inactive = { colors = { "rgba(ccd3fecc)", "rgba(8d90a3cc)" }, angle = 45 },
		},
	},
	render = { direct_scanout = 2 },
	ecosystem = { no_update_news = true, no_donation_nag = true },
	misc = {
		disable_hyprland_logo = true,
		mouse_move_focuses_monitor = true,
		initial_workspace_tracking = 0,
		swallow_regex = "^(Alacritty|kitty)$",
		enable_swallow = false,
		vrr = 1,
		mouse_move_enables_dpms = true,
		key_press_enables_dpms = true,
	},
	xwayland = { force_zero_scaling = false },
	dwindle = { preserve_split = true },
	master = { new_status = "master", new_on_top = true, mfact = 0.5 },
})

for name, points in pairs({
	linear = { { 0, 0 }, { 1, 1 } },
	md3_standard = { { 0.2, 0 }, { 0, 1 } },
	md3_decel = { { 0.05, 0.7 }, { 0.1, 1 } },
	md3_accel = { { 0.3, 0 }, { 0.8, 0.15 } },
	overshot = { { 0.05, 0.9 }, { 0.1, 1.1 } },
	crazyshot = { { 0.1, 1.5 }, { 0.76, 0.92 } },
	hyprnostretch = { { 0.05, 0.9 }, { 0.1, 1 } },
	fluent_decel = { { 0.1, 1 }, { 0.3, 1 } },
	easeInOutCirc = { { 0.85, 0 }, { 0.15, 1 } },
	easeOutCirc = { { 0, 0.55 }, { 0.45, 1 } },
	easeOutExpo = { { 0.16, 1 }, { 0.3, 1 } },
}) do
	hl.curve(name, { type = "bezier", points = points })
end

hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "md3_decel", style = "popin 60%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 2.5, bezier = "md3_decel" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "easeOutExpo", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "md3_decel", style = "slidevert" })
hl.animation({ leaf = "layers", enabled = true, speed = 1.5, bezier = "md3_decel" })

hl.layer_rule({ match = { namespace = "rofi" }, blur = true, ignore_alpha = 0.7 })
hl.layer_rule({ match = { namespace = "swaync-control-center" }, blur = true, ignore_alpha = 0.7 })
hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.7 })
hl.layer_rule({ match = { namespace = "swayosd" }, blur = true, ignore_alpha = 0.7 })

local function opacity(match, value)
	hl.window_rule({ match = match, opacity = value })
end

hl.window_rule({ match = { class = "fcitx" }, pseudo = true })
hl.window_rule({ match = { title = ".*(Godot).*" }, tile = true })

opacity({ class = "^(kitty|alacritty|Alacritty|org.wezfurlong.wezterm)$" }, "0.90 0.90")
opacity({ class = "^(gcr-prompter)$" }, "0.90 0.90")
opacity({ title = "^(Hyprland Polkit Agent)$" }, "0.90 0.90")
opacity({ class = "^(firefox)$" }, "1.00 1.00")
opacity({ class = "^(Brave-browser)$" }, "0.90 0.90")
opacity({
	class = "^(thunar|Steam|steam|steamwebhelper|Spotify|VSCodium|codium-url-handler|code|code-url-handler|terminalFileManager|org.kde.dolphin|org.kde.ark|nwg-look|qt5ct|qt6ct|yad)$",
}, "0.80 0.80")
opacity({ title = ".*(Spotify).*" }, "0.80 0.80")
opacity({ class = "^(com.github.rafostar.Clapper|discord|WebCord)$" }, "0.90 0.90")
opacity({
	class = "^(com.github.tchx84.Flatseal|hu.kramo.Cartridges|com.obsproject.Studio|gnome-boxes|app.drey.Warp|net.davidotek.pupgui2|Signal|io.gitlab.theevilskeleton.Upscaler)$",
}, "0.80 0.80")
opacity({
	class = "^(pavucontrol|org.pulseaudio.pavucontrol|blueman-manager|.blueman-manager-wrapped|nm-applet|nm-connection-editor|org.kde.polkit-kde-authentication-agent-1)$",
}, "0.80 0.70")

hl.window_rule({ match = { tag = "games" }, content = "game" })
hl.window_rule({ match = { content = "game" }, tag = "+games" })
hl.window_rule({ match = { class = "^(steam_app.*|steam_app_[0-9]+|gamescope)$" }, tag = "+games" })
hl.window_rule({
	match = { tag = "games" },
	sync_fullscreen = true,
	fullscreen = true,
	border_size = 0,
	no_shadow = true,
	no_blur = true,
	no_anim = true,
})

for _, class in ipairs({
	"qt5ct",
	"nwg-look",
	"org.kde.ark",
	"Signal",
	"com.github.rafostar.Clapper",
	"app.drey.Warp",
	"net.davidotek.pupgui2",
	"eog",
	"io.gitlab.theevilskeleton.Upscaler",
	"yad",
	"pavucontrol",
	"blueman-manager",
	".blueman-manager-wrapped",
	"nm-applet",
	"nm-connection-editor",
	"org.kde.polkit-kde-authentication-agent-1",
}) do
	hl.window_rule({ match = { class = "^(" .. class .. ")$" }, float = true })
end

hl.on("hyprland.start", function()
	hl.exec_cmd("waybar")
	hl.exec_cmd("nm-applet --indicator")
	hl.exec_cmd("wl-clipboard-history -t")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd('rm -f "$XDG_CACHE_HOME/cliphist/db"')
	hl.exec_cmd(scripts .. "/batterynotify.sh")
	hl.exec_cmd("gnome-keyring-daemon --start --foreground --components=secrets")
	hl.exec_cmd("fcitx5 -d --replace")
	hl.exec_cmd("fcitx5-remote -r")
end)

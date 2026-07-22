{pkgs, ...}: {
  # fonts.packages = with pkgs.nerd-fonts; [jetbrains-mono];
  programs.waybar = {
    enable = true;
    systemd = {
      enable = false;
      targets = ["graphical-session.target"];
    };
    settings = [
      {
        layer = "top";
        position = "top";
        mode = "dock"; # Fixes fullscreen issues
        height = 24; # 35
        exclusive = true;
        passthrough = false;
        gtk-layer-shell = true;
        ipc = true;
        fixed-center = true;
        margin-top = 10;
        margin-left = 10;
        margin-right = 10;
        margin-bottom = 0;

        modules-left = ["hyprland/workspaces"];
        # modules-center = ["clock" "custom/notification"];
        modules-center = ["idle_inhibitor" "clock"];
        modules-right = ["group/hardware" "backlight" "pulseaudio" "bluetooth" "network" "tray" "battery"];

        "custom/notification" = {
          tooltip = false;
          format = "{icon}";
          format-icons = {
            notification = "<span foreground='red'><sup></sup></span>";
            none = "";
            dnd-notification = "<span foreground='red'><sup></sup></span>";
            dnd-none = "";
            inhibited-notification = "<span foreground='red'><sup></sup></span>";
            inhibited-none = "";
            dnd-inhibited-notification = "<span foreground='red'><sup></sup></span>";
            dnd-inhibited-none = "";
          };
          return-type = "json";
          exec-if = "which swaync-client";
          exec = "swaync-client -swb";
          on-click = "swaync-client -t -sw";
          on-click-right = "swaync-client -d -sw";
          escape = true;
        };

        "custom/colour-temperature" = {
          format = "{} ";
          exec = "wl-gammarelay-rs watch {t}";
          on-scroll-up = "busctl --user -- call rs.wl-gammarelay / rs.wl.gammarelay UpdateTemperature n +100";
          on-scroll-down = "busctl --user -- call rs.wl-gammarelay / rs.wl.gammarelay UpdateTemperature n -100";
        };
        "group/hardware" = {
          orientation = "inherit";
          drawer = {
            click-to-reveal = true;
            transition-duration = 180;
            transition-left-to-right = false;
          };
          modules = ["custom/hardware" "cpu" "memory" "custom/gpuinfo"];
        };
        "custom/hardware" = {
          format = "󰍛 ";
          tooltip = false;
        };
        "custom/gpuinfo" = {
          exec = "${../../scripts/gpuinfo.sh}";
          return-type = "json";
          format = "󰢮 {text}";
          hide-empty-text = true;
          interval = 5; # once every 5 seconds
          tooltip = true;
          max-length = 1000;
        };
        "custom/icon" = {
          # format = " ";
          exec = "echo ' '";
          format = "{}";
        };
        "mpris" = {
          format = "{player_icon} {title} - {artist}";
          format-paused = "{status_icon} <i>{title} - {artist}</i>";
          player-icons = {
            default = "▶";
            spotify = "";
            mpv = "󰐹";
            vlc = "󰕼";
            firefox = "";
            chromium = "";
            kdeconnect = "";
            mopidy = "";
          };
          status-icons = {
            paused = "⏸";
            playing = "";
          };
          ignored-players = ["firefox" "chromium"];
          max-length = 30;
        };
        "temperature" = {
          hwmon-path = "/sys/class/hwmon/hwmon1/temp1_input";
          critical-threshold = 83;
          format = "{icon} {temperatureC}°C";
          format-icons = ["" "" ""];
          interval = 10;
        };
        "hyprland/language" = {
          format = "{short}"; # can use {short} and {variant}
          on-click = "${../../scripts/keyboardswitch.sh}";
        };
        "hyprland/workspaces" = {
          format = "{name} {windows}";
          disable-scroll = false;
          all-outputs = true;
          active-only = false;
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
          sort-by = "number";
          unique-icons = false;
          max-windows = 4;
          window-rewrite-group-threshold = 0;
          window-rewrite-default = "󰈙";
          format-window-separator = " ";
          window-rewrite = {
            "class<(kitty|Alacritty|alacritty)>" = "󰆍";
            "class<zen>" = "󰈹";
            "class<(code|Code|code-url-handler)>" = "󰨞";
            "class<thunar>" = "󰝰";
            "class<(discord|Discord)>" = "";
            "class<(obsidian|Obsidian)>" = "󱞁";
            "class<(Spotify|spotify)>" = "";
            "class<(github-desktop|GitHub Desktop|GitHubDesktop)>" = "";
            "class<(org.telegram.desktop|Telegram|telegram)>" = "";
            "class<(org.pwmt.zathura|zathura)>" = "";
          };
          tooltips = {
            default = "{name}: {windows}";
            empty = "";
          };
          persistent-workspaces = {
            "*" = [1 2 3 4 5 6 7 8];
          };
        };

        "hyprland/window" = {
          format = "  {}";
          separate-outputs = true;
          rewrite = {
            "harvey@hyprland =(.*)" = "$1 ";
            "(.*) — Mozilla Firefox" = "$1 󰈹";
            "(.*)Mozilla Firefox" = " Firefox 󰈹";
            "(.*) - Visual Studio Code" = "$1 󰨞";
            "(.*)Visual Studio Code" = "Code 󰨞";
            "(.*) — Dolphin" = "$1 󰉋";
            "(.*)Spotify" = "Spotify 󰓇";
            "(.*)Spotify Premium" = "Spotify 󰓇";
            "(.*)Steam" = "Steam 󰓓";
          };
          max-length = 1000;
        };

        "idle_inhibitor" = {
          format = "{icon}";
          format-icons = {
            activated = "󰥔";
            deactivated = "";
          };
        };

        "clock" = {
          format = "{:%a %d %b %R}";
          # format = "{:%R 󰃭 %d·%m·%y}";
          format-alt = "{:%I:%M %p}";
          tooltip-format = "<tt>{calendar}</tt>";
          calendar = {
            mode = "month";
            mode-mon-col = 3;
            on-scroll = 1;
            on-click-right = "mode";
            format = {
              months = "<span color='#ffead3'><b>{}</b></span>";
              weekdays = "<span color='#ffcc66'><b>{}</b></span>";
              today = "<span color='#ff6699'><b>{}</b></span>";
            };
          };
          actions = {
            on-click-right = "mode";
            on-click-forward = "tz_up";
            on-click-backward = "tz_down";
            on-scroll-up = "shift_up";
            on-scroll-down = "shift_down";
          };
        };

        "cpu" = {
          interval = 10;
          format = "󰍛 {usage}%";
          format-alt = "{icon0}{icon1}{icon2}{icon3}";
          format-icons = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
        };

        "memory" = {
          interval = 30;
          format = "󰾆 {percentage}%";
          format-alt = "󰾅 {used}GB";
          max-length = 10;
          tooltip = true;
          tooltip-format = " {used:.1f}GB/{total:.1f}GB";
        };

        "backlight" = {
          format = "{icon} {percent}%";
          format-icons = ["" "" "" "" "" "" "" "" ""];
          on-scroll-up = "${pkgs.swayosd}/bin/swayosd-client --brightness +2";
          on-scroll-down = "${pkgs.swayosd}/bin/swayosd-client --brightness -2";
        };

        "network" = {
          # on-click = "nm-connection-editor";
          # "interface" = "wlp2*"; # (Optional) To force the use of this interface
          format-wifi = "󰤨 ";
          # format-wifi = " {bandwidthDownBits}  {bandwidthUpBits}";
          # format-wifi = "󰤨 {essid}";
          format-ethernet = "󱘖 ";
          # format-ethernet = " {bandwidthDownBits}  {bandwidthUpBits}";
          format-linked = "󱘖 {ifname} (No IP)";
          format-disconnected = "󰤮 ";
          # format-disconnected = "󰤮 Disconnected";
          format-alt = "󰤨 {signalStrength}%";
          tooltip-format = "󱘖 {ipaddr}  {bandwidthUpBytes}  {bandwidthDownBytes}";
          tooltip-format-wifi = "󰤨 {essid}  {bandwidthUpBytes}  {bandwidthDownBytes}";
        };

        "bluetooth" = {
          format = "";
          # format-disabled = ""; # an empty format will hide the module
          format-connected = " {num_connections}";
          tooltip-format = " {device_alias}";
          tooltip-format-connected = "{device_enumerate}";
          tooltip-format-enumerate-connected = " {device_alias}";
          on-click = "blueman-manager";
        };

        "pulseaudio" = {
          format = "{icon} {volume}";
          format-muted = " ";
          on-click = "pavucontrol -t 3";
          tooltip-format = "{icon} {desc} // {volume}%";
          scroll-step = 4;
          on-scroll-up = "${pkgs.swayosd}/bin/swayosd-client --output-volume +4";
          on-scroll-down = "${pkgs.swayosd}/bin/swayosd-client --output-volume -4";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = ["" "" ""];
          };
        };

        "pulseaudio#microphone" = {
          format = "{format_source}";
          format-source = " {volume}%";
          format-source-muted = "";
          on-click = "pavucontrol -t 4";
          tooltip-format = "{format_source} {source_desc} // {source_volume}%";
          scroll-step = 5;
        };

        "tray" = {
          icon-size = 12;
          spacing = 5;
        };

        "battery" = {
          states = {
            good = 95;
            warning = 30;
            critical = 20;
          };
          format = "{icon} {capacity}%";
          # format-charging = " {capacity}%";
          format-charging = " {capacity}%";
          format-plugged = " {capacity}%";
          format-alt = "{time} {icon}";
          format-icons = ["󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
        };

        "custom/power" = {
          format = "{}";
          on-click = "wlogout -b 4";
          interval = 86400; # once every day
          tooltip = true;
        };
      }
    ];
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 12px;
        font-feature-settings: '"zero", "ss01", "ss02", "ss03", "ss04", "ss05", "cv31"';
        margin: 0;
        padding: 0;
        min-height: 0;
      }

      @define-color background #161a1f;
      @define-color surface #20262e;
      @define-color surface-raised #2a323c;
      @define-color border #3a4654;
      @define-color text #d8dee9;
      @define-color text-muted #8c98a5;
      @define-color accent #5b8db8;
      @define-color accent-strong #72a5d4;
      @define-color warning #c79a5b;
      @define-color critical #c66b6b;

      window#waybar {
        background: transparent;
        transition: background-color 0.2s ease;
      }

      window#waybar.hidden {
        opacity: 0.2;
      }

      tooltip {
        background: @background;
        border: 1px solid @border;
        border-radius: 8px;
      }

      tooltip label {
        color: @text;
        margin: 4px 6px;
      }

      .modules-left {
        background: transparent;
      }

      .modules-center,
      .modules-right {
        background: @surface;
        border: 1px solid @border;
        border-radius: 10px;
      }

      .modules-center {
        padding: 0 4px;
      }

      .modules-right {
        padding: 0 8px 0 0;
      }

      #backlight,
      #battery,
      #bluetooth,
      #clock,
      #cpu,
      #disk,
      #idle_inhibitor,
      #keyboard-state,
      #memory,
      #mode,
      #mpris,
      #network,
      #pulseaudio,
      #taskbar,
      #temperature,
      #tray,
      #window,
      #wireplumber,
      #workspaces,
      #custom-backlight,
      #custom-gpuinfo,
      #custom-hardware,
      #custom-icon,
      #custom-keybinds,
      #custom-keyboard,
      #custom-light_dark,
      #custom-lock,
      #custom-menu,
      #custom-notification,
      #custom-power,
      #custom-power_vertical,
      #custom-swaync,
      #custom-updater,
      #custom-waybar-mpris,
      #custom-weather {
        color: @text;
        padding: 3px 6px;
      }

      #idle_inhibitor.activated,
      #bluetooth.connected,
      #network.wifi,
      #pulseaudio.bluetooth {
        color: @accent-strong;
      }

      #battery.warning,
      #temperature.critical {
        color: @warning;
      }

      #battery.critical:not(.charging),
      #pulseaudio.muted,
      #network.disconnected,
      #network.disabled {
        color: @critical;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
      }

      #hardware {
        background: transparent;
        border-radius: 8px;
        padding: 0;
      }

      #hardware:hover {
        background: @surface-raised;
        border-radius: 9px 8px 8px 9px;
      }

      #hardware #custom-hardware {
        background: transparent;
        border-radius: 8px;
        transition: background-color 0.18s linear, color 0.18s linear;
      }

      #hardware:hover #custom-hardware {
        background: @accent;
        border-radius: 0 8px 8px 0;
        border-left: 1px solid @border;
        color: @background;
      }

      #hardware .drawer-child {
        background: transparent;
        border-radius: 0;
      }

      /* Compact empty pills expand only as windows or focus demand more room. */
      #workspaces {
        background: transparent;
        border: 0;
        box-shadow: none;
      }

      #workspaces button {
        background: transparent;
        border: 0;
        border-bottom: 0;
        border-radius: 8px;
        box-shadow: none;
        color: @text-muted;
        margin: 0 2px;
        min-width: 0;
        padding: 3px 7px;
        text-shadow: none;
        transition: background-color 0.18s linear, color 0.18s linear, padding 0.18s ease-in-out;
      }

      #workspaces button:not(.empty) {
        background: @surface;
        color: @text;
        padding: 3px 8px;
      }

      #workspaces button:hover {
        background: @surface-raised;
        color: @text;
      }

      #workspaces button.active {
        background: @accent;
        border: 0;
        box-shadow: none;
        color: @background;
        padding: 3px 12px;
      }

      /* Active empty pills retain the same horizontal expansion delta. */
      #workspaces button.empty.active {
        padding: 3px 8px;
      }

      /* Neutralize the base theme's bottom border for every workspace state. */
      .modules-left #workspaces button,
      .modules-left #workspaces button.focused,
      .modules-left #workspaces button.active {
        border-bottom: 0px solid transparent;
      }

      #workspaces button.urgent {
        color: @critical;
      }

      #taskbar button.active {
        background: @surface-raised;
      }

      #pulseaudio-slider slider,
      #backlight-slider slider {
        min-width: 0;
        min-height: 0;
        opacity: 0;
        background-image: none;
        border: none;
        box-shadow: none;
      }

      #pulseaudio-slider trough,
      #backlight-slider trough {
        min-width: 80px;
        min-height: 5px;
        border-radius: 5px;
      }

      #pulseaudio-slider highlight,
      #backlight-slider highlight {
        min-height: 5px;
        border-radius: 5px;
        background: @accent;
      }
    '';
  };
}

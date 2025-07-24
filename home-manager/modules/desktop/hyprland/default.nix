{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./programs/waybar
    ./programs/wlogout
    ./programs/rofi
    ./programs/hypridle
    ./programs/hyprlock
    ./programs/swaync
    # ./programs/dunst
  ];

  # nix.settings = {
  #   substituters = ["https://hyprland.cachix.org"];
  #   trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  # };

  home.packages = with pkgs; [
    hyprpaper
    hyprpicker
    cliphist
    grimblast
    swappy
    libnotify
    brightnessctl
    networkmanagerapplet
    pamixer
    pavucontrol
    playerctl
    waybar
    wtype
    wl-clipboard
    xdotool
    yad
    # socat # for and autowaybar.sh
    # jq # for and autowaybar.sh
  ];

  services.hyprpaper = {
    enable = true;
    settings = {
      preload = ["${../../../../wallpapers/ocean-wave-patterns.jxl}"];
      wallpaper = [",${../../../../wallpapers/ocean-wave-patterns.jxl}"];
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  xdg.configFile."hypr/icons" = {
    source = ./icons;
    recursive = true;
  };

  #test later systemd.user.targets.hyprland-session.Unit.Wants = [ "xdg-desktop-autostart.target" ];
  wayland.windowManager.hyprland = {
    enable = true;
    plugins = [
      # inputs.hyprland-plugins.packages.${pkgs.system}.hyprwinwrap
    ];
    systemd = {
      enable = true;
      variables = ["--all"];
    };
    settings = {
      "$mainMod" = "SUPER";
      "$term" = "${lib.getExe pkgs.kitty}";
      "$editor" = "code --disable-gpu";
      # "$fileManager" = "$term --class \"terminalFileManager\" -e ${terminalFileManager}";
      "$browser" = "zen";

      env = [
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "GDK_BACKEND,wayland,x11,*"
        "NIXOS_OZONE_WL,1"
        "ELECTRON_OZONE_PLATFORM_HINT,auto"
        "MOZ_ENABLE_WAYLAND,1"
        "OZONE_PLATFORM,wayland"
        "EGL_PLATFORM,wayland"
        "CLUTTER_BACKEND,wayland"
        "SDL_VIDEODRIVER,wayland"
        "QT_QPA_PLATFORM,wayland;xcb"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "QT_QPA_PLATFORMTHEME,qt6ct"
        "QT_AUTO_SCREEN_SCALE_FACTOR,1"
        "WLR_RENDERER_ALLOW_SOFTWARE,1"
        "NIXPKGS_ALLOW_UNFREE,1"
      ];
      exec-once = [
        #"[workspace 1 silent] ${terminal}"
        #"[workspace 5 silent] ${browser}"
        #"[workspace 6 silent] spotify"
        #"[workspace special silent] ${browser} --private-window"
        #"[workspace special silent] ${terminal}"

        "waybar"
        "swaync"
        "nm-applet --indicator"
        "wl-clipboard-history -t"
        "${lib.getExe' pkgs.wl-clipboard "wl-paste"} --type text --watch cliphist store" # clipboard store text data
        "${lib.getExe' pkgs.wl-clipboard "wl-paste"} --type image --watch cliphist store" # clipboard store image data
        "rm '$XDG_CACHE_HOME/cliphist/db'" # Clear clipboard
        "${./scripts/batterynotify.sh}" # battery notification
        # "${./scripts/autowaybar.sh}" # uncomment packages at the top
        "polkit-agent-helper-1"
        # "pamixer --set-volume 50"
      ];
      input = {
        kb_layout = "us,";
        kb_variant = "";
        repeat_delay = 400;
        repeat_rate = 30;

        follow_mouse = 1;

        touchpad.natural_scroll = true;

        tablet.output = "current";

        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
        force_no_accel = true;
      };
      general = {
        gaps_in = 4;
        gaps_out = 9;
        border_size = 2;
        "col.active_border" = "rgba(5c85d6ff) rgba(4d4dffff) 45deg";
        "col.inactive_border" = "rgba(b4befecc) rgba(6c7086cc) 45deg";
        resize_on_border = true;
        layout = "dwindle"; # dwindle or master
        # allow_tearing = true; # Allow tearing for games (use immediate window rules for specific games or all titles)
      };
      decoration = {
        shadow.enabled = false;
        rounding = 10;
        dim_special = 0.3;
        blur = {
          enabled = true;
          special = true;
          size = 6; # 6
          passes = 2; # 3
          new_optimizations = true;
          ignore_opacity = true;
          xray = false;
        };
      };
      group = {
        "col.border_active" = "rgba(5c85d6ff) rgba(4d4dffff) 45deg";
        "col.border_inactive" = "rgba(b4befecc) rgba(6c7086cc) 45deg";
        "col.border_locked_active" = "rgba(5c85d6ff) rgba(4d4dffff) 45deg";
        "col.border_locked_inactive" = "rgba(b4befecc) rgba(6c7086cc) 45deg";
      };
      layerrule = [
        "blur, rofi"
        "ignorezero, rofi"
        "ignorealpha 0.7, rofi"

        "blur, swaync-control-center"
        "blur, swaync-notification-window"
        "ignorezero, swaync-control-center"
        "ignorezero, swaync-notification-window"
        "ignorealpha 0.7, swaync-control-center"
        # "ignorealpha 0.8, swaync-notification-window"
        # "dimaround, swaync-control-center"
      ];
      animations = {
        enabled = true;
        bezier = [
          "linear, 0, 0, 1, 1"
          "md3_standard, 0.2, 0, 0, 1"
          "md3_decel, 0.05, 0.7, 0.1, 1"
          "md3_accel, 0.3, 0, 0.8, 0.15"
          "overshot, 0.05, 0.9, 0.1, 1.1"
          "crazyshot, 0.1, 1.5, 0.76, 0.92"
          "hyprnostretch, 0.05, 0.9, 0.1, 1.0"
          "fluent_decel, 0.1, 1, 0, 1"
          "easeInOutCirc, 0.85, 0, 0.15, 1"
          "easeOutCirc, 0, 0.55, 0.45, 1"
          "easeOutExpo, 0.16, 1, 0.3, 1"
        ];
        animation = [
          "windows, 1, 3, md3_decel, popin 60%"
          "border, 1, 10, default"
          "fade, 1, 2.5, md3_decel"
          # "workspaces, 1, 3.5, md3_decel, slide"
          "workspaces, 1, 3.5, easeOutExpo, slide"
          # "workspaces, 1, 7, fluent_decel, slidefade 15%"
          # "specialWorkspace, 1, 3, md3_decel, slidefadevert 15%"
          "specialWorkspace, 1, 3, md3_decel, slidevert"
        ];
      };
      render = {
        direct_scanout = 2; # 0 = off, 1 = on, 2 = auto (on with content type ‘game’)
      };
      ecosystem = {
        no_update_news = true;
        no_donation_nag = true;
      };
      misc = {
        disable_hyprland_logo = true;
        mouse_move_focuses_monitor = true;
        swallow_regex = "^(Alacritty|kitty)$";
        enable_swallow = true;
        vfr = true; # always keep on
        vrr = 1; # enable variable refresh rate (0=off, 1=on, 2=fullscreen only)
      };
      xwayland.force_zero_scaling = false;
      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
      };
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };
      master = {
        new_status = "master";
        new_on_top = true;
        mfact = 0.5;
      };
      windowrule = [
        #"noanim, class:^(Rofi)$
        "tile,title:(.*)(Godot)(.*)$"
        # "workspace 1, class:^(kitty|Alacritty|org.wezfurlong.wezterm)$"
        # "workspace 2, class:^(code|VSCodium|code-url-handler|codium-url-handler)$"
        # "workspace 3, class:^(krita)$"
        # "workspace 3, title:(.*)(Godot)(.*)$"
        # "workspace 3, title:(GNU Image Manipulation Program)(.*)$"
        # "workspace 3, class:^(factorio)$"
        # "workspace 3, class:^(steam)$"
        # "workspace 5, class:^(firefox|floorp|zen)$"
        # "workspace 6, class:^(Spotify)$"
        # "workspace 6, title:(.*)(Spotify)(.*)$"

        # Can use FLOAT FLOAT for active and inactive or just FLOAT
        "opacity 0.80 0.80,class:^(kitty|alacritty|Alacritty|org.wezfurlong.wezterm)$"
        "opacity 0.90 0.90,class:^(gcr-prompter)$" # keyring prompt
        "opacity 0.90 0.90,title:^(Hyprland Polkit Agent)$" # polkit prompt
        "opacity 1.00 1.00,class:^(firefox)$"
        "opacity 0.90 0.90,class:^(Brave-browser)$"
        "opacity 0.80 0.80,class:^(thunar)$"
        "opacity 0.80 0.80,class:^(Steam)$"
        "opacity 0.80 0.80,class:^(steam)$"
        "opacity 0.80 0.80,class:^(steamwebhelper)$"
        "opacity 0.80 0.80,class:^(Spotify)$"
        "opacity 0.80 0.80,title:(.*)(Spotify)(.*)$"
        "opacity 0.80 0.80,class:^(VSCodium)$"
        "opacity 0.80 0.80,class:^(codium-url-handler)$"
        "opacity 0.80 0.80,class:^(code)$"
        "opacity 0.80 0.80,class:^(code-url-handler)$"
        "opacity 0.80 0.80,class:^(terminalFileManager)$"
        "opacity 0.80 0.80,class:^(org.kde.dolphin)$"
        "opacity 0.80 0.80,class:^(org.kde.ark)$"
        "opacity 0.80 0.80,class:^(nwg-look)$"
        "opacity 0.80 0.80,class:^(qt5ct)$"
        "opacity 0.80 0.80,class:^(qt6ct)$"
        "opacity 0.80 0.80,class:^(yad)$"

        "opacity 0.90 0.90,class:^(com.github.rafostar.Clapper)$" #Clapper-Gtk
        "opacity 0.80 0.80,class:^(com.github.tchx84.Flatseal)$" #Flatseal-Gtk
        "opacity 0.80 0.80,class:^(hu.kramo.Cartridges)$" #Cartridges-Gtk
        "opacity 0.80 0.80,class:^(com.obsproject.Studio)$" #Obs-Qt
        "opacity 0.80 0.80,class:^(gnome-boxes)$" #Boxes-Gtk
        "opacity 0.90 0.90,class:^(discord)$" #Discord-Electron
        "opacity 0.90 0.90,class:^(WebCord)$" #WebCord-Electron
        "opacity 0.80 0.80,class:^(app.drey.Warp)$" #Warp-Gtk
        "opacity 0.80 0.80,class:^(net.davidotek.pupgui2)$" #ProtonUp-Qt
        "opacity 0.80 0.80,class:^(Signal)$" #Signal-Gtk
        "opacity 0.80 0.80,class:^(io.gitlab.theevilskeleton.Upscaler)$" #Upscaler-Gtk

        "opacity 0.80 0.70,class:^(pavucontrol)$"
        "opacity 0.80 0.70,class:^(org.pulseaudio.pavucontrol)$"
        "opacity 0.80 0.70,class:^(blueman-manager)$"
        "opacity 0.80 0.70,class:^(.blueman-manager-wrapped)$"
        "opacity 0.80 0.70,class:^(nm-applet)$"
        "opacity 0.80 0.70,class:^(nm-connection-editor)$"
        "opacity 0.80 0.70,class:^(org.kde.polkit-kde-authentication-agent-1)$"

        "content game, tag:games"
        "tag +games, content:game"
        "tag +games, class:^(steam_app.*|steam_app_\d+)$"
        "tag +games, class:^(gamescope)$"
        "tag +games, class:(Waydroid)"
        "tag +games, class:(osu!)"

        # Games
        "syncfullscreen,tag:games"
        "fullscreen,tag:games"
        "noborder 1,tag:games"
        "noshadow,tag:games"
        "noblur,tag:games"
        "noanim,tag:games"

        "float,class:^(qt5ct)$"
        "float,class:^(nwg-look)$"
        "float,class:^(org.kde.ark)$"
        "float,class:^(Signal)$" #Signal-Gtk
        "float,class:^(com.github.rafostar.Clapper)$" #Clapper-Gtk
        "float,class:^(app.drey.Warp)$" #Warp-Gtk
        "float,class:^(net.davidotek.pupgui2)$" #ProtonUp-Qt
        "float,class:^(eog)$" #Imageviewer-Gtk
        "float,class:^(io.gitlab.theevilskeleton.Upscaler)$" #Upscaler-Gtk
        "float,class:^(yad)$"
        "float,class:^(pavucontrol)$"
        "float,class:^(blueman-manager)$"
        "float,class:^(.blueman-manager-wrapped)$"
        "float,class:^(nm-applet)$"
        "float,class:^(nm-connection-editor)$"
        "float,class:^(org.kde.polkit-kde-authentication-agent-1)$"
      ];
      binde = [
        # Resize windows
        "$mainMod CTRL, right, resizeactive, 30 0"
        "$mainMod CTRL, left, resizeactive, -30 0"
        "$mainMod CTRL, up, resizeactive, 0 -30"
        "$mainMod CTRL, down, resizeactive, 0 30"

        # Resize windows with hjkl keys
        "$mainMod CTRL, l, resizeactive, 30 0"
        "$mainMod CTRL, h, resizeactive, -30 0"
        "$mainMod CTRL, k, resizeactive, 0 -30"
        "$mainMod CTRL, j, resizeactive, 0 30"

        # Functional keybinds
        ",XF86MonBrightnessDown,exec,brightnessctl set 2%-"
        ",XF86MonBrightnessUp,exec,brightnessctl set +2%"
        ",XF86AudioLowerVolume,exec,pamixer -d 2"
        ",XF86AudioRaiseVolume,exec,pamixer -i 2"
      ];
      bind = let
        autoclicker = pkgs.callPackage ./scripts/autoclicker.nix {};
      in
        [
          # Keybinds help menu
          # "$mainMod, question, exec, ${./scripts/keybinds.sh}"
          # "$mainMod, slash, exec, ${./scripts/keybinds.sh}"
          # "$mainMod CTRL, K, exec, ${./scripts/keybinds.sh}"

          # "$mainMod, F8, exec, kill $(cat /tmp/auto-clicker.pid) 2>/dev/null || ${lib.lib.getExe autoclicker} --cps 40"
          # "$mainMod ALT, mouse:276, exec, kill $(cat /tmp/auto-clicker.pid) 2>/dev/null || ${lib.lib.getExe autoclicker} --cps 60"

          # Night Mode (lower value means warmer temp)
          "$mainMod, F9, exec, ${lib.getExe pkgs.hyprsunset} --temperature 3500" # good values: 3500, 3000, 2500
          "$mainMod, F10, exec, pkill hyprsunset"

          # Window/Session actions
          "$mainMod, Q, exec, ${./scripts/dontkillsteam.sh}" # killactive, kill the window on focus
          "ALT, F4, exec, ${./scripts/dontkillsteam.sh}" # killactive, kill the window on focus
          "$mainMod, delete, exit" # kill hyperland session
          "$mainMod, W, togglefloating" # toggle the window on focus to float
          "$mainMod SHIFT, G, togglegroup" # toggle the window on focus to float
          "ALT, return, fullscreen" # toggle the window on focus to fullscreen
          "$mainMod ALT, L, exec, hyprlock" # lock screen
          "$mainMod, backspace, exec, pkill -x wlogout || wlogout -b 4" # logout menu
          "$CONTROL, ESCAPE, exec, pkill waybar || waybar" # toggle waybar

          # Applications/Programs
          "$mainMod, Return, exec, $term"
          "$mainMod, T, exec, $term"
          "$mainMod, F, exec, thunar"
          "$mainMod, C, exec, $editor"
          "$mainMod, B, exec, $browser"
          "$CONTROL ALT, DELETE, exec, $term -e '${lib.getExe pkgs.btop}'" # System Monitor
          "$mainMod CTRL, C, exec, hyprpicker --autocopy --format=hex" # Colour Picker

          "$mainMod, A, exec, pkill -x rofi || ${./scripts/rofi.sh} drun" # launch desktop applications
          "$CONTROL, SPACE, exec, pkill -x rofi || ${./scripts/rofi.sh} drun" # launch desktop applications
          "$mainMod, SPACE, exec, pkill -x rofi || ${./scripts/rofi.sh} drun" # launch desktop applications
          "$mainMod, E, exec, pkill -x rofi || ${./scripts/rofi.sh} emoji" # launch emoji picker
          # "$mainMod, tab, exec, pkill -x rofi || ${./scripts/rofi.sh} window" # switch between desktop applications
          # "$mainMod, R, exec, pkill -x rofi || ${./scripts/rofi.sh} file" # brrwse system files
          "$mainMod ALT, K, exec, ${./scripts/keyboardswitch.sh}" # change keyboard layout
          "$mainMod, N, exec, swaync-client -t -sw" # swayNC panel
          "$mainMod, G, exec, ${./scripts/rofi.sh} games" # game launcher
          "$mainMod ALT, G, exec, ${./scripts/gamemode.sh}" # disable hypr effects for gamemode
          "$mainMod, V, exec, ${./scripts/ClipManager.sh}" # Clipboard Manager
          "$mainMod, M, exec, pkill -x rofi || ${./scripts/rofimusic.sh}" # online music

          # Screenshot/Screencapture
          # "$mainMod, P, exec, ${./scripts/screenshot.sh} s" # drag to snip an area / click on a window to print it
          "$mainMod SHIFT, S, exec, ${./scripts/screenshot.sh} sf" # frozen screen, drag to snip an area / click on a window to print it
          "$mainMod CTRL, S, exec, ${./scripts/screenshot.sh} m" # print focused monitor
          # "$mainMod ALT, P, exec, ${./scripts/screenshot.sh} p" # print all monitor outputs

          # Functional keybinds
          ",xf86Sleep, exec, systemctl suspend" # Put computer into sleep mode
          ",XF86AudioMicMute,exec,pamixer --default-source -t" # mute mic
          ",XF86AudioMute,exec,pamixer -t" # mute audio
          ",XF86AudioPlay,exec,playerctl play-pause" # Play/Pause media
          ",XF86AudioPause,exec,playerctl play-pause" # Play/Pause media
          ",xf86AudioNext,exec,playerctl next" # go to next media
          ",xf86AudioPrev,exec,playerctl previous" # go to previous media

          # ",xf86AudioNext,exec,${./scripts/MediaCtrl.sh} next" # go to next media
          # ",xf86AudioPrev,exec,${./scripts/MediaCtrl.sh} previous" # go to previous media
          # ",XF86AudioPlay,exec,${./scripts/MediaCtrl.sh} play-pause" # go to next media
          # ",XF86AudioPause,exec,${./scripts/MediaCtrl.sh} play-pause" # go to next media

          # to switch between windows in a floating workspace
          "ALT, Tab, cyclenext"
          "ALT, Tab, bringactivetotop"

          # Switch workspaces relative to the active workspace with mainMod + CTRL + [←→]
          "$mainMod, Tab, workspace, r+1"
          "$mainMod SHIFT, Tab, workspace, r-1"

          # # move to the first empty workspace instantly with mainMod + Tab + [↓]
          # "$mainMod Tab, down, workspace, empty"

          # Move focus with mainMod + arrow keys
          "$mainMod, left, movefocus, l"
          "$mainMod, right, movefocus, r"
          "$mainMod, up, movefocus, u"
          "$mainMod, down, movefocus, d"
          # "ALT, Tab, movefocus, d"

          # Move focus with mainMod + HJKL keys
          "$mainMod, h, movefocus, l"
          "$mainMod, l, movefocus, r"
          "$mainMod, k, movefocus, u"
          "$mainMod, j, movefocus, d"

          # # Go to workspace 6 and 7 with mouse side buttons
          # "$mainMod, mouse:276, workspace, 5"
          # "$mainMod, mouse:275, workspace, 6"
          # "$mainMod SHIFT, mouse:276, movetoworkspace, 5"
          # "$mainMod SHIFT, mouse:275, movetoworkspace, 6"
          # "$mainMod CTRL, mouse:276, movetoworkspacesilent, 5"
          # "$mainMod CTRL, mouse:275, movetoworkspacesilent, 6"

          # # Rebuild NixOS with a KeyBind
          # "$mainMod, U, exec, $term -e ${./scripts/rebuild.sh}"

          # Scroll through existing workspaces with mainMod + scroll
          "$mainMod, mouse_down, workspace, e+1"
          "$mainMod, mouse_up, workspace, e-1"

          # Move active window to a relative workspace with mainMod + CTRL + ALT + [←→]
          "$mainMod CTRL ALT, right, movetoworkspace, r+1"
          "$mainMod CTRL ALT, left, movetoworkspace, r-1"

          # Move active window around current workspace with mainMod + SHIFT + CTRL [←→↑↓]
          "$mainMod SHIFT, left, movewindow, l"
          "$mainMod SHIFT, right, movewindow, r"
          "$mainMod SHIFT, up, movewindow, u"
          "$mainMod SHIFT, down, movewindow, d"

          # Move active window around current workspace with mainMod + SHIFT + CTRL [HLJK]
          "$mainMod SHIFT, H, movewindow, l"
          "$mainMod SHIFT, L, movewindow, r"
          "$mainMod SHIFT, K, movewindow, u"
          "$mainMod SHIFT, J, movewindow, d"

          # # Special workspaces (scratchpad)
          # "$mainMod CTRL, S, movetoworkspacesilent, special"
          # "$mainMod ALT, S, movetoworkspacesilent, special"
          # "$mainMod, S, togglespecialworkspace,"
        ]
        ++ (builtins.concatLists (builtins.genList (x: let
            ws = let
              c = (x + 1) / 10;
            in
              builtins.toString (x + 1 - (c * 10));
          in [
            "$mainMod, ${ws}, workspace, ${toString (x + 1)}"
            "$mainMod CTRL, ${ws}, movetoworkspace, ${toString (x + 1)}"
            "$mainMod SHIFT, ${ws}, movetoworkspacesilent, ${toString (x + 1)}"
          ])
          10));
      bindm = [
        # Move/Resize windows with mainMod + LMB/RMB and dragging
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
    };
    extraConfig = ''
      binds {
        workspace_back_and_forth = 1
        #allow_workspace_cycles=1
        #pass_mouse_when_bound=0
      }

      # Easily plug in any monitor
      monitor=,preferred,auto,1
    '';
  };
}

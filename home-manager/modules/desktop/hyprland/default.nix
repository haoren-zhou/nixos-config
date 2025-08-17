{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../common.nix
    ./binds.nix
    ./hyprpaper.nix

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

  xdg.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [xdg-desktop-portal-hyprland xdg-desktop-portal-gtk];
    xdgOpenUsePortal = true;
  };

  dconf.enable = true;
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  gtk = {
    enable = true;
    theme = {
      name = lib.mkForce "adw-gtk3-dark";
      package = lib.mkForce pkgs.adw-gtk3;
    };
    gtk2.extraConfig = ''
      gtk-application-prefer-dark-theme = true
    '';
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
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
        "gnome-keyring-daemon --start --foreground --components=secrets" # HACK: manual start
        # "pamixer --set-volume 50"
        "fcitx5-remote -r"
        "fcitx5 -d --replace &"
        "fcitx5-remote -r"
      ];
      input = {
        kb_layout = "us,cn";
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
        "col.active_border" = "rgba(6e92dbff) rgba(7878ffff) 45deg";
        "col.inactive_border" = "rgba(ccd3fecc) rgba(8d90a3cc) 45deg";
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
        "col.border_active" = "rgba(6e92dbff) rgba(7878ffff) 45deg";
        "col.border_inactive" = "rgba(ccd3fecc) rgba(8d90a3cc) 45deg";
        "col.border_locked_active" = "rgba(6e92dbff) rgba(7878ffff) 45deg";
        "col.border_locked_inactive" = "rgba(ccd3fecc) rgba(8d90a3cc) 45deg";
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
        enable_swallow = false;
        vfr = true; # always keep on
        vrr = 1; # enable variable refresh rate (0=off, 1=on, 2=fullscreen only)
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
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
        "pseudo,class:fcitx" # Pseudo window for fcitx5
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

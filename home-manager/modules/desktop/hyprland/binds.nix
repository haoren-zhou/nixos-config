{ pkgs, lib, ... }:
{
  wayland.windowManager.hyprland.settings = {
    binde = [
      # Resize windows
      "$mainMod ALT, right, resizeactive, 30 0"
      "$mainMod ALT, left, resizeactive, -30 0"
      "$mainMod ALT, up, resizeactive, 0 -30"
      "$mainMod ALT, down, resizeactive, 0 30"

      # Resize windows with hjkl keys
      "$mainMod ALT, l, resizeactive, 30 0"
      "$mainMod ALT, h, resizeactive, -30 0"
      "$mainMod ALT, k, resizeactive, 0 -30"
      "$mainMod ALT, j, resizeactive, 0 30"

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
        "$CONTROL ALT, L, exec, hyprlock" # lock screen
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
        # "$mainMod CTRL, SPACE, exec, ${./scripts/keyboardswitch.sh}" # change keyboard layout
        "$mainMod CTRL, SPACE, execr, fcitx5-remote -t" # change keyboard layout
        "$mainMod, I, execr, fcitx5-remote -t" # toggle fcitx5 input method
        "$mainMod, N, exec, swaync-client -t -sw" # swayNC panel
        "$mainMod, G, exec, ${./scripts/rofi.sh} games" # game launcher
        "$mainMod ALT, G, exec, ${./scripts/gamemode.sh}" # disable hypr effects for gamemode
        "$mainMod, V, exec, ${./scripts/ClipManager.sh}" # Clipboard Manager
        "$mainMod, M, exec, pkill -x rofi || ${./scripts/rofimusic.sh}" # online music

        # Screenshot/Screencapture
        "$mainMod SHIFT, S, exec, ${./scripts/screenshot.sh} s" # drag to snip an area / click on a window to print it
        "$mainMod CTRL, S, exec, ${./scripts/screenshot.sh} sf" # frozen screen, drag to snip an area / click on a window to print it
        "$mainMod CTRL, P, exec, ${./scripts/screenshot.sh} m" # print focused monitor
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
        "$mainMod CTRL, right, workspace, r+1"
        "$mainMod CTRL, left, workspace, r-1"
        "$mainMod CTRL, h, workspace, r-1"
        "$mainMod CTRL, l, workspace, r+1"

        # # move to the first empty workspace instantly with mainMod + CTRL + [↓]
        "$mainMod CTRL, down, workspace, empty"
        "$mainMod CTRL, j, workspace, empty"

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
}

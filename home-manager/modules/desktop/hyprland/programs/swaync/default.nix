{pkgs, ...}: {
  services.swaync = {
    enable = true;
    settings = {
      "$schema" = "${pkgs.swaynotificationcenter}/etc/xdg/swaync/configSchema.json";
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-layer = "top";
      layer-shell = true;
      layer-shell-cover-screen = true;
      ignore-gtk-theme = true;
      cssPriority = "user";
      control-center-margin-top = 22;
      control-center-margin-bottom = 2;
      control-center-margin-right = 1;
      control-center-margin-left = 0;
      notification-icon-size = 64;
      notification-body-image-height = 128;
      notification-body-image-width = 200;
      timeout = 6;
      timeout-low = 3;
      timeout-critical = 0;
      fit-to-screen = false;
      control-center-width = 400;
      control-center-height = 720;
      notification-window-width = 375;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 200;
      hide-on-clear = false;
      hide-on-action = true;
      script-fail-notify = true;
      widgets = [
        "title"
        "dnd"
        "notifications"
        "mpris"
        "volume"
        "backlight"
        "buttons-grid"
      ];
      widget-config = {
        title = {
          text = "Notification Center";
          clear-all-button = true;
          button-text = "";
        };
        notifications = {
          vexpand = true;
        };
        volume = {
          label = "";
          expand-button-label = "";
          collapse-button-label = "";
          show-per-app = true;
          show-per-app-icon = true;
          show-per-app-label = true;
        };
        backlight = {
          label = "󰃟";
        };
        dnd = {
          text = " Do Not Disturb";
        };
        mpris = {
          image-size = 96;
          image-radius = 4;
        };
        label = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "";
        };

        "buttons-grid" = {
          buttons-per-row = 4;
          actions = [
            {
              label = "󰍭";
              type = "toggle";
              command = "pamixer --default-source -t";
              update-command = "sh -c 'pamixer --get-mute --default-source | grep true && echo true || echo false'";
            }

            {
              label = "";
              type = "toggle";
              command = "blueman-manager";
              update-command = "sh -c 'bluetoothctl show | grep -q \\\"Powered: yes\\\" && echo true || echo false'";
            }

            {
              label = "󰤨";
              type = "toggle";
              command = "sh -c '[ \"$SWAYNC_TOGGLE_STATE\" = true ] && nmcli radio wifi on || nmcli radio wifi off'";
              update-command = "sh -c 'nmcli radio wifi | grep -q enabled && echo true || echo false'";
            }

            {
              label = "󰤄";
              type = "toggle";
              command = "sh -c '${pkgs.procps}/bin/pgrep -x hyprsunset >/dev/null && ${pkgs.procps}/bin/pkill hyprsunset || nohup ${pkgs.hyprsunset}/bin/hyprsunset --temperature 3500 > /tmp/hyprsunset_output.log 2>&1 &'";
              update-command = "sh -c 'pgrep -x hyprsunset >/dev/null && echo true || echo false'";
            }

            {
              label = "☕";
              command = "systemctl --user is-active --quiet hypridle.service && systemctl --user stop hypridle.service || systemctl --user start hypridle.service";
              type = "toggle";
              update-command = "pgrep -x hypridle > /dev/null && echo false || echo true";
            }

            {
              label = "";
              type = "toggle";

              command = "${../../../hyprland/scripts/TogglePowerMode.sh}";
              update-command = "powerprofilesctl get | grep -qx power-saver && echo true || echo false";
            }
            {
              label = "󰄀";
              command = "sh -c 'swaync-client -cp; ${../../../hyprland/scripts/screenshot.sh} sf'";
            }
            {
              label = "";
              command = "sh -c 'swaync-client -cp; pkill -x wlogout || wlogout -b 4'";
            }
          ];
        };
      };
      scripts = {
        example-script = {
          exec = "echo 'Do something...'";
          urgency = "Normal";
        };
      };
      notification-visibility = {
        spotify = {
          state = "enabled";
          urgency = "Low";
          app-name = "Spotify";
        };
        youtube-music = {
          state = "enabled";
          urgency = "Low";
          app-name = "com.github.th_ch.youtube_music";
        };
      };
    };
    style = builtins.readFile ./style.css;
  };
}

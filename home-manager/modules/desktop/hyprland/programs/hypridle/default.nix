{...}: {
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        ignore_dbus_inhibit = false;
        lock_cmd = "pidof hyprlock || hyprlock";
        unlock_cmd = "pkill --signal SIGUSR1 hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'";
      };
      listener = [
        {
          timeout = 300; # 5 Minutes
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 600; # 10 Minutes
          on-timeout = "hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'";
        }
        /*
           {
          timeout = 600; # 10m
          on-timeout = "systemctl suspend";
        }
        */
      ];
    };
  };
}

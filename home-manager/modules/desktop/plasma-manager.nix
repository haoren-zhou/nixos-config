{ pkgs, ... }:
{
  home.packages = with pkgs; [
    kara
    kde-rounded-corners
    kdePackages.kcalc
    kdePackages.krohnkite
    kdotool
  ];

  programs.plasma = {
    enable = true;

    # overrideConfig = true;

    workspace = {
      cursor = {
        theme = "Bibata-Modern-Ice";
        size = 24;
      };
    };

    hotkeys.commands = {
      "launch-kitty" = {
        name = "Launch Kitty";
        key = "Ctrl+Alt+T";
        command = "kitty";
      };
      "launch-ulauncher" = {
        name = "Launch ulauncher";
        key = "Ctrl+Space";
        command = "ulauncher-toggle";
      };
      "screenshot-region" = {
        name = "Capture a rectangular region of the screen";
        key = "Meta+Shift+S";
        command = "spectacle --region --nonotify";
      };
      "screenshot-screen" = {
        name = "Capture the entire desktop";
        key = "Meta+Ctrl+S";
        command = "spectacle --fullscreen --nonotify";
      };
    };

    input = {
      keyboard = {
        layouts = [
          {
            layout = "us";
          }
          {
            layout = "cn";
            variant = "pinyin";
          }
        ];
        repeatDelay = 250;
        repeatRate = 40;
      };
      # https://nix-community.github.io/plasma-manager/options.xhtml#opt-programs.plasma.input.mice
      # mice = [
      # ];
      touchpads = [
        {
          enable = true;
          disableWhileTyping = true;
          leftHanded = false;
          middleButtonEmulation = true;
          name = "ELAN1200:00 04F3:306F Touchpad";
          naturalScroll = true;
          pointerSpeed = 0;
          productId = "306f";
          tapToClick = true;
          vendorId = "04f3";
        }
      ];
    };

    krunner.activateWhenTypingOnDesktop = false;

    kscreenlocker = {
      # appearance.wallpaper = "";
      autoLock = true;
      timeout = 1800;
    };

    kwin = {
      effects = {
        blur.enable = false;
        cube.enable = false;
        desktopSwitching.animation = "off";
        dimAdminMode.enable = false;
        dimInactive.enable = false;
        fallApart.enable = false;
        fps.enable = false;
        minimization.animation = "off";
        shakeCursor.enable = false;
        slideBack.enable = false;
        snapHelper.enable = false;
        translucency.enable = false;
        windowOpenClose.animation = "off";
        wobblyWindows.enable = false;
      };

      nightLight = {
        enable = true;
        temperature.night = 4000;
        transitionTime = 30; # The time in minutes it takes to transition from day to night.
        mode = "times";
        time = {
          morning = "06:30";
          evening = "22:30";
        };
      };

      virtualDesktops = {
        number = 5;
        rows = 1;
      };
    };

    powerdevil = {
      AC = {
        autoSuspend.action = "sleep";
        autoSuspend.idleTimeout = 7200; # 2 hours

        dimDisplay.enable = true;
        dimDisplay.idleTimeout = 600; # 10 minutes

        turnOffDisplay.idleTimeout = 1800; # 30 minutes

        whenLaptopLidClosed = "turnOffScreen";
        powerButtonAction = "shutDown";
      };
      battery = {
        autoSuspend.action = "sleep";
        autoSuspend.idleTimeout = 3600; # 1 hour

        dimDisplay.enable = true;
        dimDisplay.idleTimeout = 600; # 10 minutes

        turnOffDisplay.idleTimeout = 900; # 15 minutes

        whenLaptopLidClosed = "turnOffScreen";
        powerButtonAction = "shutDown";
      };
    };

    session = {
      general.askForConfirmationOnLogout = false;
      sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";
    };
  };
}

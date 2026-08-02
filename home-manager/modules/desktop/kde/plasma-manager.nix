{pkgs, ...}: {
  home.packages = with pkgs; [
    kara
    kde-rounded-corners
    kdePackages.kcalc
    kdePackages.krohnkite
    kdotool
  ];

  programs.plasma = {
    enable = true;

    overrideConfig = true;

    workspace = {
      enableMiddleClickPaste = false;
      clickItemTo = "select";
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
      "launch-zen" = {
        name = "Launch Zen Browser";
        key = "Meta+B";
        command = "zen-beta";
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

    shortcuts = {
      ksmserver = {
        "Lock Session" = [
          "Screensaver"
          "Ctrl+Alt+L"
        ];
        "LogOut" = [
          "Ctrl+Alt+Q"
        ];
      };

      "KDE Keyboard Layout Switcher" = {
        "Switch to Next Keyboard Layout" = "Meta+Space";
      };

      kwin = {
        "KrohnkiteMonocleLayout" = [];
        "Overview" = "Meta+A";
        "Switch to Desktop 1" = "Meta+1";
        "Switch to Desktop 2" = "Meta+2";
        "Switch to Desktop 3" = "Meta+3";
        "Switch to Desktop 4" = "Meta+4";
        "Switch to Desktop 5" = "Meta+5";
        "Window Close" = "Meta+Q";
        "Window Fullscreen" = "Alt+Return";
        # "Window Move Center" = "Ctrl+Alt+C";
        "Window to Desktop 1" = "Meta+!";
        "Window to Desktop 2" = "Meta+@";
        "Window to Desktop 3" = "Meta+#";
        "Window to Desktop 4" = "Meta+$";
        "Window to Desktop 5" = "Meta+%";

        "Switch to Next Desktop" = "Meta+Tab";
        "Switch to Previous Desktop" = "Meta+Shift+Tab";

        "KrohnkiteFocusUp" = ["Meta+K" "Meta+Up"];
        "KrohnkiteFocusDown" = ["Meta+J" "Meta+Down"];
        "KrohnkiteFocusLeft" = ["Meta+H" "Meta+Left"];
        "KrohnkiteFocusRight" = ["Meta+L" "Meta+Right"];

        "KrohnkiteShiftUp" = ["Meta+Shift+K" "Meta+Shift+Up"];
        "KrohnkiteShiftDown" = ["Meta+Shift+J" "Meta+Shift+Down"];
        "KrohnkiteShiftLeft" = ["Meta+Shift+H" "Meta+Shift+Left"];
        "KrohnkiteShiftRight" = ["Meta+Shift+L" "Meta+Shift+Right"];

        "KrohnkiteShrinkWidth" = ["Meta+Ctrl+H" "Meta+Ctrl+Left"];
        "KrohnkitegrowWidth" = ["Meta+Ctrl+L" "Meta+Ctrl+Right"];
        "KrohnkiteShrinkHeight" = ["Meta+Ctrl+K" "Meta+Ctrl+Up"];
        "KrohnkiteGrowHeight" = ["Meta+Ctrl+J" "Meta+Ctrl+Down"];

        "KrohnkiteToggleFloat" = "Meta+Shift+F"; # current window only
        "KrohnkiteFloatAll" = "Meta+Ctrl+F";
      };

      plasmashell = {
        "show-on-mouse-pos" = "";
      };

      "services/org.kde.dolphin.desktop"."_launch" = "Meta+F";
    };

    spectacle = {
      shortcuts = {
        captureEntireDesktop = "";
        captureRectangularRegion = "";
        launch = "";
        recordRegion = "Meta+Shift+R";
        recordScreen = "Meta+Ctrl+R";
        recordWindow = "";
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
        repeatDelay = 400;
        repeatRate = 30;
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

    panels = [
      {
        floating = false;
        height = 34;
        lengthMode = "fill";
        location = "top";
        opacity = "translucent";
        widgets = [
          {
            name = "org.dhruv8sh.kara";
            config = {
              general = {
                animationDuration = 0;
                spacing = 3;
                type = 1;
              };
              type1 = {
                fixedLen = 3;
                labelSource = 0;
              };
            };
          }
          "org.kde.plasma.panelspacer"
          {
            name = "org.kde.plasma.digitalclock";
            config = {
              Appearance = {
                dateDisplayFormat = "BesideTime";
                dateFormat = "custom";
                use24hFormat = 2;
              };
            };
          }
          "org.kde.plasma.panelspacer"
          {
            systemTray = {
              items = {
                showAll = false;
                shown = [
                  "org.kde.plasma.battery"
                  "org.kde.plasma.keyboardlayout"
                  "org.kde.plasma.networkmanagement"
                  "org.kde.plasma.volume"
                ];
                hidden = [
                  "org.kde.plasma.brightness"
                  "org.kde.plasma.clipboard"
                  "org.kde.plasma.devicenotifier"
                  "plasmashell_microphone"
                ];
                configs = {
                  "org.kde.plasma.notifications".config = {
                    Shortcuts = {
                      global = "Meta+N";
                    };
                  };
                  "org.kde.plasma.clipboard".config = {
                    Shortcuts = {
                      global = "Meta+V";
                    };
                  };
                };
              };
            };
          }
        ];
      }
    ];

    window-rules = [
      {
        apply = {
          noborder = {
            value = true;
            apply = "initially";
          };
        };
        description = "Hide titlebar by default";
        match = {
          window-class = {
            value = ".*";
            type = "regex";
          };
        };
      }
      # {
      #   apply = {
      #     desktops = "Desktop_2";
      #     desktopsrule = "3";
      #   };
      #   description = "Assign Kitty to Desktop 2";
      #   match = {
      #     window-class = {
      #       value = "kitty";
      #       type = "substring";
      #     };
      #     window-types = ["normal"];
      #   };
      # }
    ];

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

    configFile = {
      baloofilerc."Basic Settings"."Indexing-Enabled" = false;
      kdeglobals = {
        General = {
          BrowserApplication = "zen.desktop";
        };
        KDE = {
          AnimationDurationFactor = 0;
        };
      };
      klaunchrc.FeedbackStyle.BusyCursor = false;
      klipperrc.General.MaxClipItems = 1000;
      kwinrc = {
        Effect-overview.BorderActivate = 9;
        Plugins = {
          krohnkiteEnabled = true;
          screenedgeEnabled = false;
        };
        "Round-Corners" = {
          ActiveOutlineAlpha = 255;
          ActiveOutlineUseCustom = false;
          ActiveOutlineUsePalette = true;
          ActiveSecondOutlineUseCustom = false;
          ActiveSecondOutlineUsePalette = true;
          DisableOutlineTile = false;
          DisableRoundTile = false;
          InactiveCornerRadius = 8;
          InactiveOutlineAlpha = 0;
          InactiveOutlineUseCustom = false;
          InactiveOutlineUsePalette = true;
          InactiveSecondOutlineAlpha = 0;
          InactiveSecondOutlineThickness = 0;
          OutlineThickness = 1;
          SecondOutlineThickness = 0;
          Size = 8;
        };
        "Script-krohnkite" = {
          floatingClass = "ulauncher,org.kde.kcalc";
          screenGapBetween = 3;
          screenGapBottom = 3;
          screenGapLeft = 3;
          screenGapRight = 3;
          screenGapTop = 3;
        };
        Windows = {
          DelayFocusInterval = 0;
          FocusPolicy = "FocusFollowsMouse";
        };
      };
      plasmanotifyrc = {
        DoNotDisturb.WhenScreenSharing = false;
        Notifications.PopupTimeout = 7000;
      };
      plasmarc.OSD.Enabled = false;
      spectaclerc = {
        Annotations.annotationToolType = 8;
        General = {
          launchAction = "DoNotTakeScreenshot";
          showCaptureInstructions = false;
          showMagnifier = "ShowMagnifierAlways";
          useReleaseToCapture = true;
        };
        ImageSave.imageCompressionQuality = 100;
      };
    };

    session = {
      general.askForConfirmationOnLogout = false;
      sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";
    };

    dataFile = {
      "dolphin/view_properties/global/.directory"."Dolphin"."ViewMode" = 1;
      "dolphin/view_properties/global/.directory"."Settings"."HiddenFilesShown" = true;
    };

    startup.startupScript = {
      ulauncher = {
        text = "ulauncher --hide-window";
        priority = 8;
        runAlways = true;
      };
    };
  };
}

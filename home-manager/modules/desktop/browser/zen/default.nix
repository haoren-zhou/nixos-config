{
  inputs,
  pkgs,
  ...
}: let
  package = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
  firefox-addons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
in {
  imports = [inputs.zen-browser.homeModules.beta];

  xdg.mimeApps.defaultApplicationPackages = [package];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;

    # User-locked system policies (policies.json)
    policies = {
      AutofillAddressEnabled = true;
      AutofillCreditCardEnabled = false;
      DisableAppUpdate = true;
      DisableFeedbackCommands = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
    };

    profiles.default = {
      # BetterZen: privacy/telemetry/performance prefs
      presets.betterfox.enable = true;

      settings = {
        browser.cache.disk.enable = true;
        network.dns.disablePrefetch = false;
        network.dns.disablePrefetchFromHTTPS = false;
        network.prefetch-next = true;
        network.http.speculative-parallel-limit = 6;
        browser.places.speculativeConnect.enabled = true;
        browser.urlbar.speculativeConnect.enabled = true;
      };

      search = {
        force = true;
        default = "google";
      };

      spaces = {
        "1-default" = {
          name = "Default";
          id = "eca7fae7-50ec-48af-9054-0ace348e215c";
          position = 1;
          icon = "🌐";

          pins."GitHub" = {
            id = "68ed5ad4-ce07-4f92-aae8-e1856d41831b";
            url = "https://github.com";
            position = 101;
          };
          pins."NixOS Search" = {
            id = "f34591d1-56bb-4f45-984b-5989bf531f6e";
            url = "https://search.nixos.org/packages";
            position = 102;
          };
        };
        "2-work" = {
          name = "Work";
          id = "f56048ed-146c-4762-9e65-f3e702cc4897";
          position = 2;
          icon = "💼";
        };
        "3-personal" = {
          name = "Personal";
          id = "08a23c24-2d54-4e0e-8cbb-423a9dd44bf1";
          position = 3;
          icon = "🏠";
        };
        "4-scratch" = {
          name = "Scratch";
          id = "00ed0e5e-cd15-4818-aaa3-d0d49337ce8f";
          position = 4;
          icon = "📔";
        };
      };

      # Alt+1..Alt+10 to switch to workspace N
      keyboardShortcuts =
        (map (n: {
          id = "zen-workspace-switch-${toString n}";
          key = toString n;
          modifiers.alt = true;
        }) (builtins.genList (n: n + 1) 10))
        ++ [
          # Swapped vs Zen defaults: floating sidebar Ctrl+S, compact mode Ctrl+Alt+S
          {
            id = "zen-compact-mode-show-sidebar";
            key = "s";
            modifiers.accel = true;
          }
          {
            id = "zen-compact-mode-toggle";
            key = "s";
            modifiers.accel = true;
            modifiers.alt = true;
          }
        ];
      keyboardShortcutsVersion = 19;

      mods = [
        "e122b5d9-d385-4bf8-9971-e137809097d0" # No Top Sites
        "906c6915-5677-48ff-9bfc-096a02a72379" # Floating Status Bar
      ];

      extensions.packages = with firefox-addons; [
        ublock-origin
        surfingkeys
        darkreader
        sponsorblock
      ];
    };
  };
}

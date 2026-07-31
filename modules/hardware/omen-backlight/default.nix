{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.hardware.omenBacklight;

  omen-backlight = pkgs.stdenv.mkDerivation {
    pname = "omen-backlight";
    version = "1.0.0";

    src = ./omen-backlight.c;
    dontUnpack = true;

    buildPhase = ''
      runHook preBuild
      $CC -O2 -Wall -Wextra -o omen-backlight $src
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 omen-backlight $out/bin/omen-backlight
      runHook postInstall
    '';

    meta = {
      description = "Mirror a sysfs backlight device to the HP OMEN Max EC PWM register";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
      mainProgram = "omen-backlight";
    };
  };
in {
  options.hardware.omenBacklight = {
    enable = lib.mkEnableOption ''
      panel brightness control on the HP OMEN Max 16-ah0xxx.

      In Hybrid graphics mode the firmware updates CBL1 but never propagates it
      to the EC register ECPW, so every standard backlight interface reports
      success while the panel ignores it. A daemon mirrors the chosen sysfs
      device onto ECPW to restore control
    '';

    sourceDevice = lib.mkOption {
      type = lib.types.str;
      default = "nvidia_0";
      description = ''
        Device under /sys/class/backlight to mirror onto the EC register.

        brightnessctl and swayosd both select this one by default, so the Fn
        keys, the swaync slider and the waybar scroll wheel already agree on
        it, and its 0-100 range matches the ECPW = CBL1 * 2 scaling the
        firmware uses.
      '';
    };

    minBrightness = lib.mkOption {
      type = lib.types.ints.between 0 200;
      default = 10;
      description = "Floor applied to the EC register so the panel never goes fully dark.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [omen-backlight];

    systemd.services.omen-backlight = {
      description = "Mirror ${cfg.sourceDevice} brightness to the OMEN Max EC register";

      wantedBy = ["multi-user.target"];
      after = ["systemd-backlight@backlight:${cfg.sourceDevice}.service"];

      # The daemon waits for the device itself, so no .device dependency: the
      # sys-subsystem-backlight-devices-* alias units stay inactive here.
      startLimitIntervalSec = 0;

      serviceConfig = {
        ExecStart = "${lib.getExe omen-backlight} watch /sys/class/backlight/${cfg.sourceDevice} ${toString cfg.minBrightness}";
        Restart = "on-failure";
        RestartSec = 2;

        # /dev/mem is the whole point, so PrivateDevices must stay off
        DevicePolicy = "closed";
        DeviceAllow = ["/dev/mem rw"];
        CapabilityBoundingSet = ["CAP_SYS_RAWIO"];

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictAddressFamilies = "none";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        PrivateNetwork = true;
        PrivateTmp = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = ["@system-service"];
        UMask = "0077";
      };
    };
  };
}

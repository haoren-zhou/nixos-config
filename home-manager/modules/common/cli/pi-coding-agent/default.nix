{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  configFiles = [
    "settings.json"
    "zentui.json"
    "hermes-memory-config.json"
    "pi-plan-mode.json"
    "extensions/pi-permission-system/config.json"
  ];
in {
  imports = [
    ./pi-safe
  ];

  programs.pi-safe = {
    enable = true;
    extraWritablePaths = [
      "${config.home.homeDirectory}/nixos"
      config.xdg.cacheHome
      "${config.xdg.dataHome}/pnpm"
      "${config.xdg.dataHome}/uv/python"
      "${config.xdg.dataHome}/uv/tools"
      "${config.xdg.dataHome}/direnv"
    ];
  };

  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
    pkgs.nodejs
    pkgs.poppler
    pkgs.qpdf
  ];

  home.sessionVariables.PI_CODING_AGENT_DIR = "${config.xdg.configHome}/pi/agent";

  xdg.configFile = {
    "pi/agent/extensions" = {
      # exclude pi-permission-system config file
      source = lib.cleanSourceWith {
        src = ./extensions;
        filter = path: _type: path != toString ./extensions/pi-permission-system/config.json;
      };
      recursive = true;
    };
    "pi/agent/skills" = {
      source = ./skills;
      recursive = true;
    };
  };

  # pi-safe requires bind sources to exist, including on fresh installations.
  home.activation.createPiSafeWritableDirectories = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p -- ${lib.escapeShellArgs config.programs.pi-safe.extraWritablePaths}
  '';

  # install config files as editable copies, not symlinks
  # WARN: deletes existing symlinks
  home.activation.bootstrapPiAgentConfigs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    dir="${config.xdg.configHome}/pi/agent"
    mkdir -p "$dir"
    for f in ${lib.concatStringsSep " " configFiles}; do
      target="$dir/$f"
      if [ -L "$target" ]; then
        rm -f "$target"
      fi
      if [ ! -e "$target" ]; then
        mkdir -p "$(dirname "$target")"
        install -m 0644 ${./.}/"$f" "$target"
      fi
    done
  '';
}

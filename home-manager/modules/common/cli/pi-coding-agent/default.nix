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
  ];
in {
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
    pkgs.nodejs
    pkgs.poppler
    pkgs.qpdf
  ];

  home.sessionVariables.PI_CODING_AGENT_DIR = "${config.xdg.configHome}/pi/agent";

  xdg.configFile = {
    "pi/agent/extensions" = {
      source = ./extensions;
      recursive = true;
    };
    "pi/agent/skills" = {
      source = ./skills;
      recursive = true;
    };
  };

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
        install -m 0644 ${./.}/"$f" "$target"
      fi
    done
  '';
}

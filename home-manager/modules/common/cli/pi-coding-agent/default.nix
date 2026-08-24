{
  config,
  inputs,
  pkgs,
  ...
}: {
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
    pkgs.nodejs
  ];

  home.sessionVariables.PI_CODING_AGENT_DIR = "${config.xdg.configHome}/pi/agent";

  xdg.configFile = {
    "pi/agent/settings.json".source = ./settings.json;
    "pi/agent/zentui.json".source = ./zentui.json;

    "pi/agent/extensions" = {
      source = ./extensions;
      recursive = true;
    };

    "pi/agent/skills" = {
      source = ./skills;
      recursive = true;
    };
  };
}

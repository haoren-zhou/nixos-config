{...}: {
  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;
    matchBlocks."*".extraOptions.AddKeysToAgent = "yes";
  };
}

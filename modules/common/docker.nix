{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    docker-compose
  ];
  virtualisation.docker.enable = true;
  virtualisation.docker.autoPrune.enable = true;
}

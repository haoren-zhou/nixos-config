{ inputs, pkgs, ... }:

{
  imports = [
    inputs.nix4nvchad.homeManagerModule
  ];

  programs.nvchad = {
    enable = true;
    extraPackages = with pkgs; [
      docker-compose-language-service
      dockerfile-language-server-nodejs
      nixd
      alejandra
      prettierd

      black
      isort

      clang-tools

      nodePackages.prettier
    ];
    hm-activation = true;
    backup = false;
  };
}

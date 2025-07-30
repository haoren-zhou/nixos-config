{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nix4nvchad.homeManagerModule
  ];

  programs.nvchad = {
    enable = true;
    extraPackages = with pkgs; [
      # Language Servers
      docker-compose-language-service
      dockerfile-language-server-nodejs
      vscode-langservers-extracted
      nixd
      pyright
      typescript-language-server
      marksman

      # Formatters
      alejandra
      black
      cmake-format
      isort
      nodePackages.prettier
      prettierd

      # misc
      clang-tools
      gdb
    ];
    hm-activation = true;
    backup = false;
  };
}

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
      docker-language-server
      vscode-langservers-extracted
      typescript-language-server
      tailwindcss-language-server
      nixd
      pyright
      marksman
      cmake-language-server

      # Formatters
      alejandra
      cmake-format
      nodePackages.prettier
      prettierd
      ruff

      # misc
      clang-tools
      gdb
    ];
    hm-activation = true;
    backup = false;
  };
}

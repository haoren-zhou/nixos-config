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
      typescript-language-server
      tailwindcss-language-server
      texlab
      nixd
      basedpyright
      marksman
      cmake-language-server
      ocamlPackages.ocaml-lsp

      # Formatters
      alejandra
      cmake-format
      google-java-format
      nodePackages.prettier
      prettierd
      ruff
      tex-fmt
      stylua
      ocamlPackages.ocamlformat

      # misc
      clang-tools
      # gdb
    ];
    hm-activation = true;
    backup = false;
  };
}

{
  inputs,
  pkgs,
  pkgs-unstable,
  ...
}: {
  imports = [
    inputs.nix4nvchad.homeManagerModule
  ];

  programs.nvchad = {
    enable = true;
    neovim = pkgs-unstable.neovim;
    extraPackages = with pkgs;
      [
        # Language Servers
        docker-compose-language-service
        dockerfile-language-server
        vscode-langservers-extracted
        typescript-language-server
        tailwindcss-language-server
        texlab
        nixd
        basedpyright
        marksman
        cmake-language-server
        ocamlPackages.ocaml-lsp
        jdt-language-server

        # Formatters
        alejandra
        cmake-format
        google-java-format
        prettier
        prettierd
        ruff
        tex-fmt
        stylua
        ocamlPackages.ocamlformat

        # misc
        clang-tools
        ghostscriptX
        imagemagick
        librsvg
        # python313Packages.pylatexenc
        # gdb
      ]
      ++ [pkgs-unstable.tree-sitter];
    hm-activation = true;
    backup = false;
  };
}

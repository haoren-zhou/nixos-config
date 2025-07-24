{ pkgs, ... }:

{
  programs.vscode.profiles.default = {
    extensions = with pkgs.open-vsx; with pkgs.vscode-extensions; [
      github.vscode-github-actions
      eamodio.gitlens

      bbenoist.nix
      yzhang.markdown-all-in-one
      tamasfe.even-better-toml

      ms-vscode.cpptools
      ms-vscode.cmake-tools
      ms-vscode.makefile-tools

      ms-azuretools.vscode-docker

      ms-python.python
      astral-sh.ty
      ms-toolsai.jupyter
      ms-toolsai.jupyter-renderers
      ms-toolsai.jupyter-keymap
      ms-toolsai.vscode-jupyter-cell-tags
      ms-toolsai.vscode-jupyter-slideshow

      esbenp.prettier-vscode

      ibm.output-colorizer
    ];
  };
}

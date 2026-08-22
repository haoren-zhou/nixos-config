{pkgs, ...}: {
  programs.tmux = {
    enable = true;

    sensibleOnTop = true;

    escapeTime = 10;
    baseIndex = 1;
    shortcut = "a";
    mouse = true;
    historyLimit = 10000;
    keyMode = "vi";
    terminal = "tmux-256color";

    extraConfig = ''
      set -g set-clipboard on
      # Pass truecolor through to kitty
      set -g terminal-features "xterm-kitty:RGB"

      set -g status-right '#[dim](#S) %a %d %b %H:%M'

      # Windows
      set -g renumber-windows on
      bind r command-prompt "rename-window %%"
      bind P set pane-border-status
    '';

    plugins = with pkgs.tmuxPlugins; [
      pain-control
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-vim 'session'
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];
  };
}

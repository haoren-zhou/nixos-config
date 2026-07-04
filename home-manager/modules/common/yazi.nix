{pkgs, ...}: {
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      mgr = {
        show_hidden = true;
        ratio = [1 3 4];
      };

      preview = {
        wrap = "no";
      };

      plugin.prepend_fetchers = [
        {
          id = "git";
          name = "*";
          run = "git";
        }
        {
          id = "git";
          name = "*/";
          run = "git";
        }
      ];
    };

    keymap = {
      mgr.prepend_keymap = [
        {
          on = "!";
          run = ''shell "$SHELL" --block'';
          desc = "Open $SHELL here";
          for = "unix";
        }
        {
          on = "!";
          run = ''shell "powershell.exe" --block'';
          desc = "Open PowerShell here";
          for = "windows";
        }
        {
          on = ["g" "D"];
          run = "cd ~/Documents/";
          desc = "Go ~/Documents/";
          for = "unix";
        }
      ];
    };

    initLua = ''
      require("full-border"):setup({
        type = ui.Border.ROUNDED,
      })
      require("git"):setup({
        order = 1500,
      })
    '';

    plugins = {
      full-border = pkgs.yaziPlugins.full-border;
      git = pkgs.yaziPlugins.git;
    };

    flavors = {
      gruvbox-dark = pkgs.fetchFromGitHub {
        owner = "bennyyip";
        repo = "gruvbox-dark.yazi";
        rev = "619fdc5844db0c04f6115a62cf218e707de2821e";
        hash = "sha256-Y/i+eS04T2+Sg/Z7/CGbuQHo5jxewXIgORTQm25uQb4=";
      };
    };

    theme.flavor.dark = "gruvbox-dark";
  };
}

{
  config,
  pkgs,
  ...
}: let
  userName = "haoren-zhou";
  userEmail = "hrz9009@gmail.com";
in {
  programs.git = {
    enable = true;
    userName = userName;
    userEmail = userEmail;

    signing = {
      format = "ssh";
      key = "~/.ssh/id_ed25519.pub";
      signByDefault = true;
    };

    extraConfig = {
      init.defaultBranch = "main";
      url."git@github.com:".insteadOf = "https://github.com/";
      gpg.ssh.allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
    };
  };
}

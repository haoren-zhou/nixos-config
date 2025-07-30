{
  config,
  pkgs,
  ...
}: {
  programs.git = {
    enable = true;
    userName = "haoren-zhou";
    userEmail = "hrz9009@gmail.com";
  };
}

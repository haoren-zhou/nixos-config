{
  config,
  pkgs,
  ...
}: {
  programs.micro = {
    enable = true;
    settings = {
      autosu = true;
      tabsize = 2;
      tabstospaces = true;
      softwrap = true;
    };
  };
}

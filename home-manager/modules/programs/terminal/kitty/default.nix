{
  programs.kitty = {
    enable = true;
    settings = {
      strip_trailing_spaces = "smart";
      copy_on_select = "yes";
      confirm_os_window_close = 0;
      scrollback_lines = 10000;
      enable_audio_bell = false;
      mouse_hide_wait = 60;
      update_check_interval = 0;
    };
  };
}
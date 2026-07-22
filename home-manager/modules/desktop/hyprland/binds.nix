{lib, ...}: {
  wayland.windowManager.hyprland.extraConfig = lib.mkAfter (builtins.readFile ./binds.lua);
}

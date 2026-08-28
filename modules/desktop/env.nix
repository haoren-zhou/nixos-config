{
  # Keep the runtime directory override scoped to graphical sessions.
  environment.variables.XDG_RUNTIME_DIR = "/run/user/$UID";

  environment.sessionVariables.TERMINAL = "kitty";
}

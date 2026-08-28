{config, ...}: {
  environment.sessionVariables = rec {
    EDITOR = "nvim";
    XDG_BIN_HOME = "$HOME/.local/bin";
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    PATH = [
      "${XDG_BIN_HOME}"
    ];

    # Make the NixOS CA bundle visible to non-Nix binaries (e.g. uv Python).
    SSL_CERT_FILE = config.security.pki.caBundle;
  };
}

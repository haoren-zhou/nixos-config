{lib}: rec {
  colors = {
    background = "#111318";
    surface = "#1d2026";
    surface-raised = "#252a32";
    border = "#3d4550";
    text = "#e2e7ee";
    text-muted = "#a4abb5";
    accent = "#77a8d5";
    accent-strong = "#a5c8ed";
    warning = "#d5a15e";
    critical = "#d67b7b";
  };

  defineColors =
    lib.concatMapStrings
    (name: "@define-color ${name} ${colors.${name}};\n")
    (lib.attrNames colors);
}

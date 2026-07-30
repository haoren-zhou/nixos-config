{lib}: rec {
  colors = {
    background = "#111318";
    surface = "#1d2026";
    surface-raised = "#252a32";
    border = "#3d4550";
    border-active = "#6e92db";
    border-active-alt = "#7878ff";
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

  # Names are prefixed because rasi has no separate variable namespace, and
  # `border`, `text` and `background` are real rofi properties.
  rasiColors =
    "* {\n"
    + lib.concatMapStrings
    (name: "  c-${name}: ${colors.${name}};\n")
    (lib.attrNames colors)
    + "  c-background-blur: ${colors.background}cc;\n"
    + "}\n";
}

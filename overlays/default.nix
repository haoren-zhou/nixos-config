{
  inputs,
  ...
}: {
  # Overlay custom derivations into nixpkgs so you can use pkgs.<name>
  additions = final: _prev:
    import ../pkgs {
      pkgs = final;
    };
}

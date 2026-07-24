# Repository Guidelines

## Project Structure & Module Organization

This repository is a Nix flake for NixOS hosts and Home Manager profiles. `flake.nix` declares inputs, the `hosts` inventory, and all system/home outputs. Put host-specific entrypoints in `hosts/<hostname>/`; keep generated `hardware-configuration.nix` files with their host.

NixOS modules live in `modules/common/`, `modules/desktop/`, and `modules/hardware/`. Home Manager is organized similarly: use `home-manager/packages/` for package lists, `profiles/` for composition entrypoints, and `modules/common/` or `modules/desktop/` for program configuration. The `nvim/` directory is the NvChad configuration submodule; `wallpapers/` holds image assets and conversion helpers.

## Build, Test, and Development Commands

- `nix flake check` evaluates the flake and its declared configurations; run it before submitting Nix changes.
- `nix build '.#nixosConfigurations.<host>.config.system.build.toplevel'` builds one system without switching it.
- `nix build '.#homeConfigurations."hr@<host>".activationPackage'` builds a Home Manager activation package.
- `nh os switch` and `nh home switch` apply the current machine's configuration. Use these only on the intended host after validation.

## Coding Style & Naming Conventions

Follow the existing Nix style: two-space indentation, one attribute per line when lists are non-trivial, and relative imports grouped in `imports = [ ... ];`. Use lowercase, hyphenated filenames where appropriate (for example, `hardware-configuration.nix`); use a directory with `default.nix` for a multi-file module. Keep common settings independent of desktop-only dependencies, and register every new module in the relevant `default.nix` or profile.

No repository-wide formatter is configured. Preserve surrounding formatting and run an available Nix formatter consistently over files you edit rather than making unrelated formatting changes.

## Testing Guidelines

There is no unit-test framework or coverage target. Treat flake evaluation and the smallest relevant build as required checks. For a new host, validate both its NixOS output and its `hr@<host>` Home Manager output. Do not switch live configurations merely to test an unrelated change.

## Commit & Pull Request Guidelines

Recent history uses concise imperative Conventional Commit messages, such as `feat(kilat): add new device`, `fix: update package names`, and `docs: update README`. Scope commits to one logical change and include regenerated `flake.lock` only when inputs intentionally change.

Pull requests should state the affected hosts/profiles, summarize user-visible configuration changes, list validation commands and results, and link related issues. Include screenshots only for visual desktop changes when they clarify the result.

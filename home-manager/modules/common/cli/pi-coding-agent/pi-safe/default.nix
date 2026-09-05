{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.pi-safe;
  pi = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;

  piSafe = pkgs.writeShellApplication {
    name = "pi-safe";
    runtimeInputs = [
      pkgs.bubblewrap
      pkgs.coreutils
      pi
    ];
    text = ''
      set -euo pipefail

      mode="${cfg.defaultMode}"
      if (($# > 0)); then
        case "$1" in
          readonly|restricted|unrestricted)
            mode="$1"
            shift
            ;;
        esac
      fi

      case "$mode" in
        unrestricted)
          exec pi "$@"
          ;;
        readonly|restricted)
          ;;
        *)
          printf 'pi-safe: unknown mode: %s\n' "$mode" >&2
          printf 'usage: pi-safe [readonly|restricted|unrestricted] [pi options...]\n' >&2
          exit 64
          ;;
      esac

      project_dir=$(pwd -P)
      agent_dir="''${PI_CODING_AGENT_DIR:-''${XDG_CONFIG_HOME:-$HOME/.config}/pi/agent}"

      [[ -d "$project_dir" ]] || {
        printf 'pi-safe: project directory does not exist: %s\n' "$project_dir" >&2
        exit 1
      }
      if [[ "$mode" == restricted && "$project_dir" == / ]]; then
        printf 'pi-safe: refusing to make the host root writable in restricted mode\n' >&2
        exit 64
      fi
      [[ "$agent_dir" = /* ]] || {
        printf 'pi-safe: Pi agent directory must be absolute: %s\n' "$agent_dir" >&2
        exit 64
      }
      mkdir -p -- "$agent_dir"
      agent_dir=$(realpath -e -- "$agent_dir")
      if [[ "$agent_dir" == / ]]; then
        printf 'pi-safe: Pi agent directory cannot be the root directory\n' >&2
        exit 64
      fi

      if [[ "$mode" == readonly ]]; then
        project_mount=(--ro-bind "$project_dir" "$project_dir")
      else
        project_mount=(--bind "$project_dir" "$project_dir")
      fi

      agent_mount=(
        --${
        if cfg.agentDirectoryWritable
        then "bind"
        else "ro-bind"
      }
        "$agent_dir"
        "$agent_dir"
      )

      extra_writable_paths=()
      if [[ "$mode" == restricted ]]; then
        configured_writable_paths=(${lib.escapeShellArgs cfg.extraWritablePaths})
        for writable_path in "''${configured_writable_paths[@]}"; do
          [[ "$writable_path" = /* ]] || {
            printf 'pi-safe: writable paths must be absolute: %s\n' "$writable_path" >&2
            exit 64
          }
          [[ -d "$writable_path" ]] || {
            printf 'pi-safe: writable directory does not exist: %s\n' "$writable_path" >&2
            exit 1
          }
          writable_path=$(realpath -e -- "$writable_path")
          if [[ "$writable_path" == / ]]; then
            printf 'pi-safe: refusing to make the host root an extra writable path\n' >&2
            exit 64
          fi
          extra_writable_paths+=("$writable_path")
        done
      fi

      path_is_inside() {
        local child=$1
        local parent=$2
        if [[ "$parent" == / ]]; then
          [[ "$child" == /* ]]
        else
          [[ "$child" == "$parent" || "$child" == "$parent/"* ]]
        fi
      }

      runtime_dir="/run/user/$(id -u)"
      host_runtime_dir="''${XDG_RUNTIME_DIR:-$runtime_dir}"
      bwrap_args=(
        --die-with-parent
        --new-session
        --unshare-ipc
        --unshare-pid
        --ro-bind / /
        --proc /proc
        --dev /dev
        --tmpfs /tmp
        --tmpfs /run
        --dir /run/systemd
        --ro-bind-try /run/current-system /run/current-system
        --ro-bind-try /run/systemd/resolve /run/systemd/resolve
        --dir /run/user
        --dir "$runtime_dir"
        --chmod 0700 "$runtime_dir"
        --setenv XDG_RUNTIME_DIR "$runtime_dir"
        --setenv PI_CODING_AGENT_DIR "$agent_dir"
        --unsetenv DBUS_SESSION_BUS_ADDRESS
        --unsetenv DBUS_SYSTEM_BUS_ADDRESS
      )

      expose_socket() {
        local source=$1
        local destination="''${2:-$1}"
        if [[ "$source" = /* && "$destination" = /* && -S "$source" ]]; then
          bwrap_args+=(
            --dir "$(dirname -- "$destination")"
            --ro-bind "$source" "$destination"
          )
        fi
      }

      expose_readonly_file() {
        local source=$1
        if [[ "$source" = /* && -f "$source" ]]; then
          bwrap_args+=(
            --dir "$(dirname -- "$source")"
            --ro-bind "$source" "$source"
          )
        fi
      }

      # Preserve explicitly requested desktop and authentication integration
      # without exposing the rest of the host runtime directory.
      if [[ -n "''${SSH_AUTH_SOCK:-}" ]]; then
        expose_socket "$SSH_AUTH_SOCK"
      fi
      if [[ -n "''${GPG_AGENT_INFO:-}" ]]; then
        expose_socket "''${GPG_AGENT_INFO%%:*}"
      fi
      if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
        if [[ "$WAYLAND_DISPLAY" = /* ]]; then
          expose_socket "$WAYLAND_DISPLAY"
        else
          expose_socket "$host_runtime_dir/$WAYLAND_DISPLAY" "$runtime_dir/$WAYLAND_DISPLAY"
        fi
      fi
      if [[ -n "''${XAUTHORITY:-}" ]]; then
        expose_readonly_file "$XAUTHORITY"
      fi
      if [[ "''${DISPLAY:-}" =~ ^(:|unix:)([0-9]+) ]]; then
        expose_socket "/tmp/.X11-unix/X''${BASH_REMATCH[2]}"
      fi

      # Mount broad writable exceptions first, then the project and agent
      # directory so their more specific permissions cannot be overridden.
      for writable_path in "''${extra_writable_paths[@]}"; do
        bwrap_args+=(--bind "$writable_path" "$writable_path")
      done

      # Mount the parent before the child so overlapping paths keep their
      # intended permissions. The agent directory is an explicit runtime
      # exception and is therefore writable when configured that way.
      if path_is_inside "$project_dir" "$agent_dir"; then
        bwrap_args+=("''${agent_mount[@]}" "''${project_mount[@]}")
      else
        bwrap_args+=("''${project_mount[@]}" "''${agent_mount[@]}")
      fi

      # A host tmux server can run unsandboxed commands. Discover this user's
      # running servers, not just the one named by TMUX: sessions launched
      # outside tmux (or with several servers) must mask their sockets too.
      # This snapshots existing pathname sockets at startup; it does not block
      # new host servers or socket paths created after the sandbox starts.
      declare -A tmux_socket_inodes=()
      for process_dir in /proc/[0-9]*; do
        [[ -O "$process_dir" ]] || continue
        IFS= read -r process_name 2>/dev/null < "$process_dir/comm" || continue
        [[ "$process_name" == "tmux: server" ]] || continue
        for socket_fd in "$process_dir"/fd/*; do
          socket_link=$(readlink -- "$socket_fd" 2>/dev/null) || continue
          if [[ "$socket_link" == "socket:["*"]" ]]; then
            socket_inode="''${socket_link#socket:[}"
            socket_inode="''${socket_inode%]}"
            tmux_socket_inodes["$socket_inode"]=1
          fi
        done
      done

      declare -A tmux_socket_paths=()
      while read -r _ _ _ socket_flags _ _ socket_inode socket_path; do
        if [[ "$socket_flags" == 00010000 && "$socket_path" == /* &&
              -n "''${tmux_socket_inodes[$socket_inode]:-}" ]]; then
          tmux_socket_paths["$socket_path"]=1
        fi
      done < /proc/net/unix

      # Retain the explicit current-server fallback; remove the two numeric
      # suffixes from the right so commas in a socket path are preserved.
      tmux_socket="''${TMUX:-}"
      tmux_socket="''${tmux_socket%,*}"
      tmux_socket="''${tmux_socket%,*}"
      if [[ "$tmux_socket" == /* ]]; then
        tmux_socket_paths["$tmux_socket"]=1
      fi
      for tmux_socket in "''${!tmux_socket_paths[@]}"; do
        [[ -S "$tmux_socket" ]] || continue
        tmux_socket=$(realpath -e -- "$tmux_socket")
        bwrap_args+=(--ro-bind /dev/null "$tmux_socket")
      done
      # TMUX/TMUX_PANE remain unchanged as metadata, not host access grants.

      exec bwrap "''${bwrap_args[@]}" --chdir "$project_dir" -- pi "$@"
    '';
  };
in {
  options.programs.pi-safe = {
    enable = lib.mkEnableOption "the Bubblewrap wrapper for Pi";

    defaultMode = lib.mkOption {
      type = lib.types.enum ["readonly" "restricted" "unrestricted"];
      default = "restricted";
      description = "Mode used when pi-safe is invoked without an explicit mode.";
    };

    extraWritablePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional absolute directories writable in restricted mode.";
    };

    agentDirectoryWritable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Keep Pi's agent directory writable inside the sandbox. This preserves
        sessions, package installs, and runtime state, but lets Pi modify its
        own extensions and configuration.
      '';
    };
  };

  config = lib.mkIf config.programs.pi-safe.enable {
    home.packages = [piSafe];
  };
}

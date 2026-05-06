{
  writeShellApplication,
  caddy,
  coreutils,
  caddyAuthFile ? null,
}:

let
  defaultAuthFile = if caddyAuthFile != null then caddyAuthFile else "$HOME/.caddy-basicauth";
in
writeShellApplication {
  name = "caddy-pwd";

  runtimeInputs = [
    caddy
    coreutils
  ];

  text = ''
    set -euo pipefail

    auth_file="${defaultAuthFile}"
    username="admin"
    use_stdin=0
    force=0

    usage() {
      cat <<EOF
    Usage: caddy-pwd [--username USERNAME] [--file PATH] [--stdin] [--force]

    Create or replace the Caddy basic-auth file used by this setup.

    Options:
      --username USERNAME  Username to store (default: admin)
      --file PATH          Destination file (default: ${defaultAuthFile})
      --stdin              Read the password from stdin
      --force              Overwrite an existing file without prompting
      -h, --help           Show this help text
    EOF
    }

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --username)
          shift
          if [[ $# -eq 0 ]]; then
            printf 'Missing value for --username\n' >&2
            exit 1
          fi
          username="$1"
          ;;
        --file)
          shift
          if [[ $# -eq 0 ]]; then
            printf 'Missing value for --file\n' >&2
            exit 1
          fi
          auth_file="$1"
          ;;
        --stdin)
          use_stdin=1
          ;;
        --force)
          force=1
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          printf 'Unknown argument: %s\n' "$1" >&2
          usage >&2
          exit 1
          ;;
      esac
      shift
    done

    if [[ -z "$username" || "$username" == *:* ]]; then
      printf 'Username must be non-empty and must not contain a colon\n' >&2
      exit 1
    fi

    prompt_secret() {
      local prompt="$1"
      local value

      if [[ ! -t 0 && ! -t 1 ]]; then
        printf 'No terminal available for password prompt. Use --stdin instead.\n' >&2
        exit 1
      fi

      IFS= read -r -s -p "$prompt" value < /dev/tty
      printf '\n' > /dev/tty
      REPLY="$value"
    }

    password=""
    confirm_password=""

    if [[ "$use_stdin" -eq 1 ]]; then
      IFS= read -r password || true
      if [[ -z "$password" ]]; then
        printf 'Expected a non-empty password on stdin\n' >&2
        exit 1
      fi
    else
      prompt_secret 'New Caddy password: '
      password="$REPLY"
      prompt_secret 'Confirm password: '
      confirm_password="$REPLY"

      if [[ -z "$password" ]]; then
        printf 'Password must not be empty\n' >&2
        exit 1
      fi

      if [[ "$password" != "$confirm_password" ]]; then
        printf 'Passwords did not match\n' >&2
        exit 1
      fi
    fi

    if [[ -e "$auth_file" && "$force" -ne 1 ]]; then
      if [[ ! -t 0 && ! -t 1 ]]; then
        printf '%s already exists. Re-run with --force to overwrite it.\n' "$auth_file" >&2
        exit 1
      fi

      IFS= read -r -p "Overwrite $auth_file? [y/N] " overwrite < /dev/tty
      case "$overwrite" in
        y|Y|yes|YES)
          ;;
        *)
          printf 'Aborted\n' >&2
          exit 1
          ;;
      esac
    fi

    auth_directory="$(dirname "$auth_file")"
    mkdir -p "$auth_directory"
    umask 077

    tmp_file="$(mktemp "$auth_directory/.caddy-basicauth.XXXXXX")"
    cleanup() {
      rm -f "$tmp_file"
    }
    trap cleanup EXIT

    auth_hash="$(caddy hash-password --plaintext "$password" | tr -d '\r\n')"
    password=""
    confirm_password=""

    if [[ "$auth_hash" != '$'* ]]; then
      printf 'Failed to generate a bcrypt hash with caddy\n' >&2
      exit 1
    fi

    printf '%s:%s\n' "$username" "$auth_hash" > "$tmp_file"
    chmod 600 "$tmp_file"
    mv -f "$tmp_file" "$auth_file"
    trap - EXIT

    printf 'Wrote %s\n' "$auth_file"
  '';
}

#!/usr/bin/env bash

set -euo pipefail

# ── Defaults ───────────────────────────────────────────────────────────────────
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/dev_env.tsv"
PROFILE_FILE=""
OS=""
DRY_RUN=false

# ── Logging ────────────────────────────────────────────────────────────────────
log()  { printf '[dev_env] %s\n' "$*"; }
warn() { printf '[dev_env] WARN: %s\n' "$*" >&2; }
die()  { printf '[dev_env] ERROR: %s\n' "$*" >&2; exit 1; }

# ── Utilities ──────────────────────────────────────────────────────────────────
command_exists() { command -v "$1" >/dev/null 2>&1; }

append_to_profile() {
  local line="$1"
  if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] would append to ${PROFILE_FILE}: ${line}"
    return
  fi
  if ! grep -qF "$line" "$PROFILE_FILE" 2>/dev/null; then
    log "  → ${PROFILE_FILE}: ${line}"
    printf '%s\n' "$line" >> "$PROFILE_FILE"
  fi
}

# ── Argument parsing ───────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

  -c, --config  <file>   Config TSV file (default: dev_env.tsv)
  -p, --profile <file>   Shell profile to update (auto-detected if omitted)
  -n, --dry-run          Log actions without installing anything or writing to the profile
  -h, --help             Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--config)  CONFIG_FILE="$2"; shift 2 ;;
      -p|--profile) PROFILE_FILE="$2"; shift 2 ;;
      -n|--dry-run) DRY_RUN=true; shift ;;
      -h|--help)    usage; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -f "$CONFIG_FILE" ]] || die "Config file not found: $CONFIG_FILE"
}

# ── OS detection ───────────────────────────────────────────────────────────────
detect_os() {
  case "$(uname -s)" in
    Darwin) OS="mac" ;;
    Linux)  OS="linux" ;;
    *) die "Unsupported OS: $(uname -s)" ;;
  esac
  log "Detected OS: $OS"
}

# ── Shell profile ──────────────────────────────────────────────────────────────
detect_profile() {
  if [[ -n "$PROFILE_FILE" ]]; then
    log "Using specified profile: $PROFILE_FILE"
    return
  fi
  case "${SHELL##*/}" in
    zsh)  PROFILE_FILE="${HOME}/.zprofile" ;;
    bash) PROFILE_FILE="${HOME}/.bash_profile" ;;
    fish) PROFILE_FILE="${HOME}/.config/fish/config.fish" ;;
    *)    PROFILE_FILE="${HOME}/.profile" ;;
  esac
  log "Auto-detected profile: $PROFILE_FILE"
  if [[ ! -f "$PROFILE_FILE" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      log "[dry-run] would create $PROFILE_FILE"
    else
      log "Creating $PROFILE_FILE"
      touch "$PROFILE_FILE"
    fi
  fi
}

# ── Linux prerequisites ────────────────────────────────────────────────────────
bootstrap_linux_deps() {
  [[ "$OS" == "linux" ]] || return 0

  local pm=""
  if   command_exists apt-get; then pm="apt-get"
  elif command_exists dnf;     then pm="dnf"
  elif command_exists yum;     then pm="yum"
  elif command_exists pacman;  then pm="pacman"
  else die "No supported package manager found (apt-get, dnf, yum, pacman) — cannot install Homebrew prerequisites"; fi

  if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] would install Homebrew prerequisites via $pm if any of: curl git gcc file are missing"
    return
  fi

  # Only call sudo if something is actually missing
  if command_exists curl && command_exists git && command_exists gcc && command_exists file; then
    log "Linux prerequisites already satisfied"
    return
  fi

  log "Installing Homebrew prerequisites via $pm..."
  case "$pm" in
    apt-get) sudo apt-get update -qq && sudo apt-get install -y build-essential curl file git ;;
    dnf)     sudo dnf install -y gcc make curl file git ;;
    yum)     sudo yum install -y gcc make curl file git ;;
    pacman)  sudo pacman -Sy --noconfirm base-devel curl file git ;;
  esac
}

# ── Homebrew bootstrap ─────────────────────────────────────────────────────────
bootstrap_brew() {
  if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] would bootstrap Homebrew if not installed"
    return
  fi
  if ! command_exists brew; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || die "Failed to install Homebrew"
  fi

  # After a fresh install brew may not yet be on PATH — eval shellenv for this session
  if ! command_exists brew; then
    if [[ "$OS" == "mac" ]]; then
      [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon
      [[ -x /usr/local/bin/brew    ]] && eval "$(/usr/local/bin/brew shellenv)"      # Intel
    elif [[ "$OS" == "linux" ]]; then
      [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]] \
        && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
  fi

  command_exists brew || die "brew not found after install — check Homebrew output above"
  log "Updating Homebrew..."
  brew update || warn "brew update failed — continuing"
}

# ── Package installers ─────────────────────────────────────────────────────────
brew_install() {
  local pkg="$1"
  if [[ "$DRY_RUN" == true ]]; then log "[dry-run] would install $pkg via brew"; return; fi
  if brew list "$pkg" >/dev/null 2>&1; then
    if brew outdated | grep -q "^${pkg}"; then
      log "Upgrading $pkg"
      brew upgrade "$pkg"
    else
      log "$pkg already up to date"
    fi
  else
    log "Installing $pkg"
    brew install "$pkg"
  fi
}

brew_cask_install() {
  local pkg="$1"
  if [[ "$DRY_RUN" == true ]]; then log "[dry-run] would install $pkg via brew cask"; return; fi
  if brew list --cask "$pkg" >/dev/null 2>&1; then
    if brew outdated --cask | grep -q "^${pkg}"; then
      log "Upgrading cask $pkg"
      brew upgrade --cask "$pkg"
    else
      log "Cask $pkg already up to date"
    fi
  else
    log "Installing cask $pkg"
    brew install --cask "$pkg"
  fi
}

curl_script_install() {
  local name="$1" url="$2"
  [[ -n "$url" ]] || die "curl_script entry '$name' requires a URL in the extra column"
  if [[ "$DRY_RUN" == true ]]; then log "[dry-run] would install $name via curl script: $url"; return; fi
  log "Installing $name via script: $url"
  curl -fsSL "$url" | bash
}

pyenv_install() {
  local version="$1" extra="${2:-}"
  if [[ "$DRY_RUN" == true ]]; then log "[dry-run] would install Python $version via pyenv${extra:+ ($extra)}"; return; fi
  command_exists pyenv \
    || die "pyenv not found — add a 'pyenv\tbrew' entry before pyenv version entries"
  eval "$(pyenv init -)" 2>/dev/null || true

  if pyenv versions --bare | grep -qx "$version"; then
    log "Python $version already installed"
  else
    log "Installing Python $version via pyenv"
    pyenv install "$version"
  fi

  if [[ "$extra" == "global" ]]; then
    log "Setting pyenv global to $version"
    pyenv global "$version"
  fi
}

nvm_install() {
  local version="$1" extra="${2:-}"
  if [[ "$DRY_RUN" == true ]]; then log "[dry-run] would install Node $version via nvm${extra:+ ($extra)}"; return; fi
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  [[ -s "$nvm_dir/nvm.sh" ]] \
    || die "nvm not found at $nvm_dir — add a curl_script entry for nvm before nvm version entries"
  # shellcheck source=/dev/null
  \. "$nvm_dir/nvm.sh"

  log "Installing Node $version via nvm"
  nvm install "$version"

  if [[ "$extra" == "default" ]]; then
    log "Setting nvm default to $version"
    nvm alias default "$version"
  fi
}

# ── Config processing ──────────────────────────────────────────────────────────
process_packages() {
  # Use \x01 as split sentinel — tab is IFS whitespace and collapses when consecutive,
  # which would swallow empty middle columns. \x01 is non-whitespace so it never collapses.
  local section="" name method extra raw sep=$'\x01'
  log "Processing packages from $CONFIG_FILE"

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    [[ "$raw" =~ ^[[:space:]]*# || -z "${raw// }" ]] && continue
    IFS="$sep" read -r name method extra <<< "${raw//$'\t'/$sep}"

    if [[ "$name" =~ ^\[ ]]; then
      section="$name"
      continue
    fi
    [[ "$section" == "[packages]" ]] || continue
    [[ "$name" == "name" ]] && continue  # skip header row

    case "$method" in
      brew)        brew_install "$name" ;;
      brew_cask)   brew_cask_install "$name" ;;
      curl_script) curl_script_install "$name" "${extra:-}" ;;
      pyenv)       pyenv_install "$name" "${extra:-}" ;;
      nvm)         nvm_install "$name" "${extra:-}" ;;
      *) warn "Unknown method '$method' for '$name' — skipping" ;;
    esac
  done < "$CONFIG_FILE"
}

write_shell_profile() {
  local section="" type key value raw sep=$'\x01'
  log "Writing profile entries to $PROFILE_FILE"

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    [[ "$raw" =~ ^[[:space:]]*# || -z "${raw// }" ]] && continue
    IFS="$sep" read -r type key value <<< "${raw//$'\t'/$sep}"

    if [[ "$type" =~ ^\[ ]]; then
      section="$type"
      continue
    fi
    [[ "$section" == "[profile]" ]] || continue
    [[ "$type" == "type" ]] && continue  # skip header row

    case "$type" in
      export) append_to_profile "export ${key}=${value}" ;;
      path)   append_to_profile "export PATH=\"${value}:\$PATH\"" ;;
      alias)  append_to_profile "alias ${key}='${value}'" ;;
      line)   append_to_profile "${value}" ;;
      *) warn "Unknown profile type '$type' — skipping" ;;
    esac
  done < "$CONFIG_FILE"
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  detect_os
  detect_profile
  bootstrap_linux_deps
  bootstrap_brew
  process_packages
  write_shell_profile
  if [[ "$DRY_RUN" == true ]]; then
    log "Dry-run complete — no changes were made"
  else
    log "Done! Reload your shell or run: source ${PROFILE_FILE}"
  fi
}

main "$@"

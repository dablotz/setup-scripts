# setup-scripts

A config-driven developer environment bootstrap for macOS and Linux. Installs packages via Homebrew, pyenv, nvm, or curl-based installers, and writes exports, PATH additions, and aliases to your shell profile — all from a single TSV file.

## Quick start

```bash
# dry-run first to verify what will happen
./dev_env.sh --dry-run

# run for real
./dev_env.sh
```

Homebrew is bootstrapped automatically if not already installed.

## Options

| Flag | Description |
|------|-------------|
| `-c, --config <file>` | Config TSV file (default: `dev_env.tsv` next to the script) |
| `-p, --profile <file>` | Shell profile to write to (auto-detected from `$SHELL` if omitted) |
| `-n, --dry-run` | Log every action without installing anything or modifying your profile |
| `-h, --help` | Show usage |

Auto-detected profiles: `~/.zprofile` (zsh), `~/.bash_profile` (bash), `~/.config/fish/config.fish` (fish), `~/.profile` (other).

## Config file format

The config is a tab-separated file with two sections. Lines beginning with `#` and blank lines are ignored.

### `[packages]`

Columns: `name`, `method`, `extra`

| method | what it does | `extra` |
|--------|-------------|---------|
| `brew` | `brew install <name>` | — |
| `brew_cask` | `brew install --cask <name>` | — |
| `curl_script` | downloads and pipes to bash | URL (required) |
| `pyenv` | `pyenv install <version>` | `global` — sets as pyenv global |
| `nvm` | `nvm install <version>` | `default` — sets as nvm default |

**Order matters**: `pyenv` must appear before any `pyenv` version entries; the `nvm` curl_script entry must appear before any `nvm` version entries.

### `[profile]`

Columns: `type`, `key`, `value`

| type | written to profile | `key` | `value` |
|------|-------------------|-------|---------|
| `export` | `export KEY=VALUE` | variable name | value |
| `path` | `export PATH="VALUE:$PATH"` | — | path to prepend |
| `alias` | `alias key='value'` | alias name | command |
| `line` | verbatim | — | any shell line |

All profile writes are idempotent — existing lines are never duplicated.

### Example

```tsv
[packages]
name	method	extra
git	brew
pyenv	brew
3.11.9	pyenv	global
nvm	curl_script	https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh
20	nvm	default
visual-studio-code	brew_cask

[profile]
type	key	value
export	NVM_DIR	$HOME/.nvm
export	EDITOR	code --wait
path		$HOME/.local/bin
alias	ll	ls -la
line		[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
line		if command -v pyenv 1>/dev/null 2>&1; then eval "$(pyenv init -)"; fi
```

## Testing

### macOS — dry-run test (no installs)

```bash
./test/run_tests_mac.sh
```

Runs the script with `--dry-run` against the minimal test config and asserts expected output. No packages are installed and your profile is not modified.

### Linux — Docker integration test

```bash
./test/run_tests.sh
```

Builds an Ubuntu 22.04 container, mounts the script and test config, and runs a full install including Homebrew bootstrap. Requires Docker. First run takes several minutes for the Homebrew bootstrap; subsequent runs are faster due to image layer caching.

To inspect the container after a failure:

```bash
docker run -it --rm \
  -v "$PWD/dev_env.sh:/home/devuser/dev_env.sh:ro" \
  -v "$PWD/test/dev_env_test.tsv:/home/devuser/dev_env.tsv:ro" \
  --entrypoint /bin/bash dev-env-test
```

## License

MIT — see [LICENSE](LICENSE).

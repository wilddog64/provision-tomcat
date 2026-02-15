# Vagrant Bundler Environment Conflict

## Problem

When running Kitchen tests with `kitchen-vagrant`, Vagrant crashes with errors like:

```
/opt/vagrant/embedded/lib/ruby/3.2.0/rubygems.rb:259:in `find_spec_for_exe': can't find gem bundler (>= 0.a) with executable bundle (Gem::GemNotFoundException)
```

Or other Ruby/Bundler related errors.

## Root Cause

Kitchen-vagrant runs under rbenv Ruby + Bundler, which pollutes the environment with variables like:

- `GEM_PATH`
- `GEM_HOME`
- `RUBYOPT`
- `BUNDLE_GEMFILE`
- `BUNDLE_BIN_PATH`

Vagrant ships its own embedded Ruby at `/opt/vagrant/embedded/` and **must not** see any of these variables. When it does, Vagrant's Ruby loads the wrong Bundler/gems and crashes.

## Solution

Create a wrapper script that runs Vagrant with a completely clean environment using `env -i`.

### 1. Create `bin/vagrant-wrapper`

```bash
#!/usr/bin/env bash
# Wrapper that gives Vagrant a completely clean environment.

ENV_ARGS=(
  HOME="$HOME"
  PATH="/opt/vagrant/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  TERM="${TERM:-dumb}"
  LANG="${LANG:-en_US.UTF-8}"
  USER="$USER"
  SHELL="$SHELL"
  TMPDIR="${TMPDIR:-/tmp}"
)

[[ -n "${SSH_AUTH_SOCK:-}" ]] && ENV_ARGS+=( SSH_AUTH_SOCK="$SSH_AUTH_SOCK" )
[[ -n "${VAGRANT_CWD:-}" ]]  && ENV_ARGS+=( VAGRANT_CWD="$VAGRANT_CWD" )
[[ -n "${DISPLAY:-}" ]]      && ENV_ARGS+=( DISPLAY="$DISPLAY" )

exec env -i "${ENV_ARGS[@]}" vagrant "$@"
```

### 2. Configure Kitchen to use the wrapper

In `.kitchen.yml`:

```yaml
driver:
  name: vagrant
  vagrant_binary: <%= File.join(File.dirname(__FILE__), 'bin', 'vagrant-wrapper') %>
```

### 3. For GitHub Actions CI

Create a similar wrapper in `$HOME/.local/bin/vagrant`:

```yaml
- name: Workaround Vagrant Bundler Conflict
  run: |
    mkdir -p $HOME/.local/bin
    cat <<'EOF' > $HOME/.local/bin/vagrant
    #!/bin/bash
    ENV_ARGS=(
      HOME="$HOME"
      PATH="/opt/vagrant/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      TERM="${TERM:-dumb}"
      LANG="${LANG:-en_US.UTF-8}"
      USER="$USER"
      SHELL="$SHELL"
      TMPDIR="${TMPDIR:-/tmp}"
    )
    [[ -n "${SSH_AUTH_SOCK:-}" ]] && ENV_ARGS+=( SSH_AUTH_SOCK="$SSH_AUTH_SOCK" )
    [[ -n "${VAGRANT_CWD:-}" ]]  && ENV_ARGS+=( VAGRANT_CWD="$VAGRANT_CWD" )
    exec /usr/bin/env -i "${ENV_ARGS[@]}" /usr/local/bin/vagrant "$@"
    EOF
    chmod +x $HOME/.local/bin/vagrant
    echo "$HOME/.local/bin" >> $GITHUB_PATH
```

## Why env -i?

Rather than playing whack-a-mole with individual environment variables, `env -i` starts from a blank slate and only forwards what Vagrant actually needs:

| Variable | Purpose |
|----------|---------|
| `HOME` | User home directory |
| `PATH` | System paths only (no rbenv/bundler) |
| `TERM` | Terminal type |
| `LANG` | Locale settings |
| `USER`, `SHELL` | User identity |
| `TMPDIR` | Temp directory |
| `SSH_AUTH_SOCK` | SSH agent (for git operations) |
| `VAGRANT_CWD` | Vagrant working directory override |

## Related Issues

- Similar approach used in `provision-jenkins` repository
- See also: [CI Robustness Fixes](2026-02-04-ci-robustness-fixes.md)

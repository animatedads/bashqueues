#!/usr/bin/env bash
# bashqueues system installer
#
# Installs bashqueues into a shared system location and, where practical, uses
# bashqueues itself to perform the privileged installation steps.  The installer
# runs a temporary private root queue so it does not accidentally dispatch any
# existing root jobs.
set -euo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
prefix="${PREFIX:-/usr/local}"
with_cron=0
with_daemon=0
with_remote_listener=0
force_root_key=0
no_root_key=0
lock_policy=0
dryrun=0
keep_tmp=0
queue_root=""

usage() {
  cat <<USAGE
Usage: sudo ./install-system.sh [options]

Options:
  --prefix DIR          Install under DIR (default: /usr/local)
  --with-cron           Install and enable the bashqueues cron bridge timer
  --without-cron        Do not install cron bridge support (default)
  --with-daemon         Install and enable the root multi-user bashqueues daemon
  --without-daemon      Do not install the system daemon (default)
  --with-remote-listener Install and enable the remote queue management listener
  --without-remote-listener
                        Do not install remote queue management listener (default)
  --queue-root DIR      Root user's queue root for key setup (default: /root/.queuebash)
  --force-root-key      Replace root's authorisation key if it exists
  --no-root-key         Do not generate/install a root authorisation key
  --lock-policy         chmod 0444 the installed shared class policy file after edits
  --dryrun              Print the installation plan only
  --keep-tmp            Keep the temporary dogfood queue/scripts for inspection
  -h, --help            Show this help

The installer creates/updates:
  PREFIX/share/bashqueues/queuebash.sh and bundled support files
  PREFIX/bin/queue wrapper for non-interactive commands
  /etc/profile.d/bashqueues.sh for interactive shell use
  /etc/bashqueues/policies.d for shared policy files
  /root/.queuebash/keys for the root authorisation/code signing key, unless disabled
  code/plugin signature policy under /etc/bashqueues/policies.d/code-signing

Cron support is optional and does not replace /usr/bin/crontab.
The system daemon is optional and starts user-owned workers for ready queues.
USAGE
}

while (($#)); do
  case "$1" in
    --prefix) prefix="${2:?missing DIR for --prefix}"; shift 2 ;;
    --with-cron) with_cron=1; shift ;;
    --without-cron) with_cron=0; shift ;;
    --with-daemon) with_daemon=1; shift ;;
    --without-daemon) with_daemon=0; shift ;;
    --with-remote-listener) with_remote_listener=1; shift ;;
    --without-remote-listener) with_remote_listener=0; shift ;;
    --queue-root) queue_root="${2:?missing DIR for --queue-root}"; shift 2 ;;
    --force-root-key) force_root_key=1; shift ;;
    --no-root-key) no_root_key=1; shift ;;
    --lock-policy) lock_policy=1; shift ;;
    --dryrun) dryrun=1; shift ;;
    --keep-tmp) keep_tmp=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install-system.sh: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$(id -u)" != "0" ]]; then
  echo "install-system.sh must be run as root" >&2
  exit 1
fi

if [[ ! -f "$src_dir/queuebash.sh" ]]; then
  echo "install-system.sh: queuebash.sh not found beside installer: $src_dir" >&2
  exit 1
fi

queue_root="${queue_root:-/root/.queuebash}"
share_dir="$prefix/share/bashqueues"
libexec_dir="$prefix/libexec/bashqueues"
bin_dir="$prefix/bin"
policy_dir="/etc/bashqueues/policies.d"
profile_file="/etc/profile.d/bashqueues.sh"
install_queue="/tmp/bashqueues-system-install-queue.$$"
work_dir="/tmp/bashqueues-system-install.$$"

cat <<PLAN
bashqueues system install plan
  source:        $src_dir
  prefix:        $prefix
  share:         $share_dir
  libexec:       $libexec_dir
  bin:           $bin_dir
  policy dir:    $policy_dir
  profile:       $profile_file
  root queue:    $queue_root
  cron bridge:   $([[ "$with_cron" == 1 ]] && echo yes || echo no)
  system daemon: $([[ "$with_daemon" == 1 ]] && echo yes || echo no)
  remote listener: $([[ "$with_remote_listener" == 1 ]] && echo yes || echo no)
  root key:      $([[ "$no_root_key" == 1 ]] && echo disabled || echo enabled)
  dogfood queue: $install_queue
PLAN

if [[ "$dryrun" == 1 ]]; then
  exit 0
fi

rm -rf "$install_queue" "$work_dir"
mkdir -p "$install_queue" "$work_dir"
cleanup() {
  if [[ "$keep_tmp" != 1 ]]; then
    rm -rf "$install_queue" "$work_dir"
  else
    echo "Kept temporary installer state:"
    echo "  $install_queue"
    echo "  $work_dir"
  fi
}
trap cleanup EXIT

cat > "$work_dir/install-core.sh" <<'STEP'
#!/usr/bin/env bash
set -euo pipefail
src_dir="$1"; prefix="$2"
share_dir="$prefix/share/bashqueues"
libexec_dir="$prefix/libexec/bashqueues"
bin_dir="$prefix/bin"
policy_dir="/etc/bashqueues/policies.d"

install -d -m 0755 "$share_dir" "$libexec_dir" "$bin_dir" /etc/bashqueues "$policy_dir"
install -m 0755 "$src_dir/queuebash.sh" "$share_dir/queuebash.sh"

for item in queuemgr_panel.py queuemgr.sh COPYING_NOTE.md; do
  [[ -e "$src_dir/$item" ]] || continue
  install -m 0755 "$src_dir/$item" "$share_dir/$item"
done
# publish_to_github.sh is a local/operator helper, not a system-installed runtime component.
# It can perform SSH/Git operations and must not be copied into /usr/local/share/bashqueues.
rm -f -- "$share_dir/publish_to_github.sh"

for dir in assets.d caps.d reporters.d classes envs.d policies.d docs bin systemd tests; do
  [[ -d "$src_dir/$dir" ]] || continue
  install -d -m 0755 "$share_dir/$dir"
  # Preserve tree contents but do not delete local additions under share.
  cp -a "$src_dir/$dir/." "$share_dir/$dir/"
  find "$share_dir/$dir" -type d -exec chmod 0755 {} + 2>/dev/null || true
  find "$share_dir/$dir" -type f -name '*.sh' -exec chmod 0755 {} + 2>/dev/null || true
  find "$share_dir/$dir" -type f ! -name '*.sh' -exec chmod 0644 {} + 2>/dev/null || true
  if [[ "$dir" == "bin" ]]; then
    find "$share_dir/$dir" -type f -exec chmod 0755 {} + 2>/dev/null || true
  fi
done

# Install shared policy templates without overwriting site edits.
if [[ -d "$src_dir/policies.d" ]]; then
  find "$src_dir/policies.d" -type f -name '*.env' | while IFS= read -r f; do
    rel="${f#$src_dir/policies.d/}"
    dst="$policy_dir/$rel"
    install -d -m 0755 "$(dirname "$dst")"
    if [[ ! -e "$dst" ]]; then
      install -m 0644 "$f" "$dst"
      echo "Installed shared policy: $dst"
    else
      echo "Keeping existing shared policy: $dst"
    fi
  done
fi

# Provide a command wrapper for non-interactive use.  Interactive shells should
# still source queuebash.sh so the queue function can affect the current shell.
cat > "$bin_dir/queue" <<EOFWRAP
#!/usr/bin/env bash
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source "$share_dir/queuebash.sh"
queue "\$@"
EOFWRAP
chmod 0755 "$bin_dir/queue"

cat > /etc/profile.d/bashqueues.sh <<EOFPROFILE
# bashqueues system profile
# Provides the queue shell function for interactive shells.
if [ -f "$share_dir/queuebash.sh" ]; then
  . "$share_dir/queuebash.sh"
fi
EOFPROFILE
chmod 0644 /etc/profile.d/bashqueues.sh

# Compatibility symlink for the queue manager shim.
ln -sf "$share_dir/queuemgr.sh" "$bin_dir/queuemgr"

echo "Installed bashqueues core under $share_dir"
STEP
chmod 0755 "$work_dir/install-core.sh"

cat > "$work_dir/install-root-key.sh" <<'STEP'
#!/usr/bin/env bash
set -euo pipefail
prefix="$1"; queue_root="$2"; force_root_key="$3"; lock_policy="$4"
share_dir="$prefix/share/bashqueues"
policy_file="/etc/bashqueues/policies.d/class-statement/default.env"

source "$share_dir/queuebash.sh"
export QUEUEBASH_ROOT="$queue_root"
mkdir -p "$QUEUEBASH_ROOT"

key_args=(authorisation root)
if [[ "$force_root_key" == 1 ]]; then
  key_args+=(--force)
fi

if [[ "$force_root_key" == 1 || ! -s "$QUEUEBASH_ROOT/keys/private/root.ed25519.pem" || ! -s "$QUEUEBASH_ROOT/keys/public/root.ed25519.pub.pem" ]]; then
  queue keygen "${key_args[@]}"
else
  echo "Keeping existing root authorisation key: $QUEUEBASH_ROOT/keys/private/root.ed25519.pem"
fi

pub="$QUEUEBASH_ROOT/keys/public/root.ed25519.pub.pem"
if [[ ! -s "$pub" ]]; then
  echo "root public key not found after key setup: $pub" >&2
  exit 1
fi

sha="$(sha256sum "$pub" | awk '{print $1}')"
b64="$(base64 -w0 "$pub" 2>/dev/null || base64 "$pub" | tr -d '\n')"
install -d -m 0755 "$(dirname "$policy_file")"
if [[ ! -e "$policy_file" ]]; then
  if [[ -f "$share_dir/policies.d/class-statement/default.env" ]]; then
    install -m 0644 "$share_dir/policies.d/class-statement/default.env" "$policy_file"
  else
    cat > "$policy_file" <<'EOFDEFAULT'
QUEUEBASH_POLICY_KIND=class-statement
QUEUEBASH_POLICY_NAME=default
CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="if-trusted-key"
EOFDEFAULT
    chmod 0644 "$policy_file"
  fi
fi
chmod u+w "$policy_file" 2>/dev/null || true

if grep -q '^CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_SHA256=' "$policy_file"; then
  current="$(grep '^CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_SHA256=' "$policy_file" | tail -1 | cut -d= -f2- | tr -d '"')"
  if [[ -n "$current" && "$current" != "$sha" ]]; then
    echo "Shared policy already declares a different ROOT public key; leaving it unchanged:" >&2
    echo "  file:    $policy_file" >&2
    echo "  current: $current" >&2
    echo "  root:    $sha" >&2
  elif [[ -z "$current" ]]; then
    tmp="$(mktemp)"
    awk -v sha="$sha" -v b64="$b64" '
      /^CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_SHA256=/ { print "CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_SHA256=" sha; seen_sha=1; next }
      /^CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_PEM_B64=/ { print "CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_PEM_B64=" b64; seen_b64=1; next }
      { print }
      END {
        if (!seen_sha) print "CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_SHA256=" sha
        if (!seen_b64) print "CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_PEM_B64=" b64
      }
    ' "$policy_file" > "$tmp"
    cat "$tmp" > "$policy_file"
    rm -f "$tmp"
    echo "Installed ROOT public key into $policy_file"
  else
    echo "ROOT public key already installed in $policy_file"
  fi
else
  {
    echo
    echo "# Installed by bashqueues system installer: trusted root authorisation signer."
    echo "CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_SHA256=$sha"
    echo "CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_PEM_B64=$b64"
  } >> "$policy_file"
  echo "Installed ROOT public key into $policy_file"
fi

if ! grep -q '^CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED=' "$policy_file"; then
  echo 'CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="if-trusted-key"' >> "$policy_file"
fi

chmod 0644 "$policy_file" 2>/dev/null || true

# Code/plugin signing: trust the root public key, sign the installed tree, and
# verify it in warn mode.  Enforcement remains a site policy decision.
code_policy="/etc/bashqueues/policies.d/code-signing/default.env"
install -d -m 0755 "$(dirname "$code_policy")"
if [[ ! -e "$code_policy" && -f "$share_dir/policies.d/code-signing/default.env" ]]; then
  install -m 0644 "$share_dir/policies.d/code-signing/default.env" "$code_policy"
elif [[ ! -e "$code_policy" ]]; then
  cat > "$code_policy" <<'EOFCODEPOL'
QUEUEBASH_CODE_SIGNATURE_MODE="warn"
QUEUEBASH_PLUGIN_SIGNATURE_MODE="${QUEUEBASH_CODE_SIGNATURE_MODE}"
QUEUEBASH_CODE_TRUSTED_PUBLIC_KEY_SHA256S=""
EOFCODEPOL
fi
chmod u+w "$code_policy" 2>/dev/null || true
if ! grep -q "$sha" "$code_policy" 2>/dev/null; then
  {
    echo
    echo "# Installed by bashqueues system installer: trusted root code/plugin signer."
    existing="$(grep '^QUEUEBASH_CODE_TRUSTED_PUBLIC_KEY_SHA256S=' "$code_policy" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"' || true)"
    echo "QUEUEBASH_CODE_TRUSTED_PUBLIC_KEY_SHA256S=\"${existing} ${sha}\""
  } >> "$code_policy"
  echo "Installed ROOT public key into $code_policy for code/plugin signing"
fi

QUEUEBASH_ROOT="$queue_root" QUEUEBASH_CODE_SIGNATURE_MODE=warn queue code sign --tree "$share_dir" --key root --signer-root "$queue_root" >/dev/null || {
  echo "warning: code signing of installed tree failed" >&2
}
QUEUEBASH_ROOT="$queue_root" QUEUEBASH_CODE_SIGNATURE_MODE=warn queue code verify --tree "$share_dir" --mode warn >/dev/null || {
  echo "warning: code signature verification reported issues" >&2
}

if [[ "$lock_policy" == 1 ]]; then
  chmod 0444 "$policy_file" "$code_policy" 2>/dev/null || true
fi
STEP
chmod 0755 "$work_dir/install-root-key.sh"

cat > "$work_dir/install-cron.sh" <<'STEP'
#!/usr/bin/env bash
set -euo pipefail
src_dir="$1"; prefix="$2"
libexec="$prefix/libexec/bashqueues"
share="$prefix/share/bashqueues"

install -d -m 1777 /var/spool/bashqueues_cron
install -d -m 0755 /etc/bashqueues_cron.d /var/lib/bashqueues/cron "$libexec" "$prefix/bin" "$share"
chmod 1777 /var/spool/bashqueues_cron 2>/dev/null || true
install -m 0755 "$src_dir/bin/bashqueues-cron-ticker.py" "$libexec/bashqueues-cron-ticker.py"
install -m 0755 "$src_dir/bin/bashqueues-crontab" "$prefix/bin/bashqueues-crontab"
install -m 0755 "$src_dir/queuebash.sh" "$share/queuebash.sh"

if command -v systemctl >/dev/null 2>&1; then
  install -m 0644 "$src_dir/systemd/bashqueues-cron.service" /etc/systemd/system/bashqueues-cron.service
  install -m 0644 "$src_dir/systemd/bashqueues-cron.timer" /etc/systemd/system/bashqueues-cron.timer
  systemctl daemon-reload
  systemctl enable --now bashqueues-cron.timer
  echo "Enabled bashqueues-cron.timer"
else
  echo "systemctl not found; cron bridge files installed but timer was not enabled" >&2
fi

echo "Installed bashqueues cron bridge"
STEP
chmod 0755 "$work_dir/install-cron.sh"

cat > "$work_dir/install-daemon.sh" <<'STEP'
#!/usr/bin/env bash
set -euo pipefail
src_dir="$1"; prefix="$2"
install -d -m 0755 /etc/systemd/system "$prefix/bin" "$prefix/share/bashqueues"
tmp_service="$(mktemp)"
sed "s#/usr/local/bin/queue#$prefix/bin/queue#g" "$src_dir/systemd/bashqueues-daemon.service" > "$tmp_service"
install -m 0644 "$tmp_service" /etc/systemd/system/bashqueues-daemon.service
rm -f "$tmp_service"
if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload
  systemctl enable --now bashqueues-daemon.service
  echo "Enabled bashqueues-daemon.service"
else
  echo "systemctl not found; bashqueues-daemon.service installed but not enabled" >&2
fi
echo "Installed bashqueues system daemon"
STEP
chmod 0755 "$work_dir/install-daemon.sh"

cat > "$work_dir/install-remote-listener-policy.sh" <<'STEP'
#!/usr/bin/env bash
set -euo pipefail
src_dir="$1"; prefix="$2"
bin_dir="$prefix/bin"
share_dir="$prefix/share/bashqueues"
policy_dir="/etc/bashqueues/policies.d/remote-queue"
state_dir="/var/lib/queuebash/remote-queue-management"
queue_root="/var/lib/queuebash/remote-queue-root"
audit_dir="/var/log/queuebash"

install -d -m 0755 "$bin_dir" "$share_dir/bin" "$share_dir/docs" "$share_dir/policies.d/remote-queue" "$policy_dir" "$state_dir" "$queue_root" "$audit_dir"
install -d -m 0750 "$policy_dir/secrets"
install -m 0755 "$src_dir/bin/queue-remote-management-listener.py" "$share_dir/bin/queue-remote-management-listener.py"
ln -sf "$share_dir/bin/queue-remote-management-listener.py" "$bin_dir/queue-remote-management-listener"

install -m 0644 "$src_dir/docs/REMOTE_QUEUE_MANAGEMENT_LISTENER.md" "$share_dir/docs/REMOTE_QUEUE_MANAGEMENT_LISTENER.md"
install -m 0644 "$src_dir/policies.d/remote-queue/remote-management.env.example" "$share_dir/policies.d/remote-queue/remote-management.env.example"
install -m 0644 "$src_dir/policies.d/remote-queue/clients.example.tsv" "$share_dir/policies.d/remote-queue/clients.example.tsv"
install -m 0644 "$src_dir/policies.d/remote-queue/acl.example.tsv" "$share_dir/policies.d/remote-queue/acl.example.tsv"

if [[ ! -e "$policy_dir/remote-management.env" ]]; then
  install -m 0644 "$src_dir/policies.d/remote-queue/remote-management.env.example" "$policy_dir/remote-management.env"
  echo "Installed remote management policy: $policy_dir/remote-management.env"
else
  echo "Keeping existing remote management policy: $policy_dir/remote-management.env"
fi
if [[ ! -e "$policy_dir/clients.tsv" ]]; then
  install -m 0640 "$src_dir/policies.d/remote-queue/clients.example.tsv" "$policy_dir/clients.tsv"
  echo "Installed disabled client registry template: $policy_dir/clients.tsv"
else
  echo "Keeping existing remote management client registry: $policy_dir/clients.tsv"
fi
if [[ ! -e "$policy_dir/acl.tsv" ]]; then
  install -m 0640 "$src_dir/policies.d/remote-queue/acl.example.tsv" "$policy_dir/acl.tsv"
  echo "Installed deny-by-default ACL template: $policy_dir/acl.tsv"
else
  echo "Keeping existing remote management ACL: $policy_dir/acl.tsv"
fi
chmod 0750 "$policy_dir" "$policy_dir/secrets" 2>/dev/null || true
echo "Installed bashqueues remote queue management listener policy files"
STEP
chmod 0755 "$work_dir/install-remote-listener-policy.sh"

cat > "$work_dir/install-remote-listener-service.sh" <<'STEP'
#!/usr/bin/env bash
set -euo pipefail
src_dir="$1"; prefix="$2"
bin_dir="$prefix/bin"
share_dir="$prefix/share/bashqueues"
install -d -m 0755 /etc/systemd/system

# Keep service file prefix-aware.
tmp_service="$(mktemp)"
sed   -e "s#/usr/local/bin/queue-remote-management-listener#$bin_dir/queue-remote-management-listener#g"   -e "s#/usr/local/share/bashqueues#$share_dir#g"   "$src_dir/systemd/bashqueues-remote-management.service" > "$tmp_service"
install -m 0644 "$tmp_service" /etc/systemd/system/bashqueues-remote-management.service
rm -f "$tmp_service"

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload
  systemctl enable --now bashqueues-remote-management.service
  echo "Enabled bashqueues-remote-management.service"
else
  echo "systemctl not found; remote management service installed but not enabled" >&2
fi
echo "Installed bashqueues remote queue management listener service"
STEP
chmod 0755 "$work_dir/install-remote-listener-service.sh"

cat > "$work_dir/install-remote-listener-verify.sh" <<'STEP'
#!/usr/bin/env bash
set -euo pipefail
prefix="$1"
bin_dir="$prefix/bin"
policy_dir="/etc/bashqueues/policies.d/remote-queue"
for required_remote_policy in \
  "$policy_dir/remote-management.env" \
  "$policy_dir/acl.tsv" \
  "$policy_dir/clients.tsv"; do
  if [[ ! -f "$required_remote_policy" ]]; then
    echo "install-system.sh: remote listener policy file was not installed: $required_remote_policy" >&2
    exit 1
  fi
done
if [[ ! -x "$bin_dir/queue-remote-management-listener" ]]; then
  echo "install-system.sh: remote listener wrapper was not installed: $bin_dir/queue-remote-management-listener" >&2
  exit 1
fi
if [[ ! -f /etc/systemd/system/bashqueues-remote-management.service ]]; then
  echo "install-system.sh: remote listener systemd unit was not installed" >&2
  exit 1
fi
echo "Verified bashqueues remote queue management listener install"
echo "Configure clients in $policy_dir/clients.tsv and grants in $policy_dir/acl.tsv"
STEP
chmod 0755 "$work_dir/install-remote-listener-verify.sh"

# Dogfood the installation through an isolated temporary queue so this installer
# does not dispatch any existing root queue work.
export QUEUEBASH_ROOT="$install_queue"
export QUEUEBASH_SUBMIT_REASON_DEFAULT="bashqueues system installer"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck source=/dev/null
source "$src_dir/queuebash.sh"

queue submit system-install-core --reason "install bashqueues system files" -- bash "$work_dir/install-core.sh" "$src_dir" "$prefix"
if [[ "$no_root_key" != 1 ]]; then
  queue submit system-install-root-key --after-success system-install-core --reason "install root authorisation signing key" -- bash "$work_dir/install-root-key.sh" "$prefix" "$queue_root" "$force_root_key" "$lock_policy"
fi
if [[ "$with_cron" == 1 ]]; then
  dep="system-install-core"
  [[ "$no_root_key" != 1 ]] && dep="system-install-root-key"
  queue submit system-install-cron --after-success "$dep" --reason "install bashqueues cron bridge" -- bash "$work_dir/install-cron.sh" "$src_dir" "$prefix"
fi
if [[ "$with_daemon" == 1 ]]; then
  dep="system-install-core"
  [[ "$with_cron" == 1 ]] && dep="system-install-cron"
  [[ "$with_cron" != 1 && "$no_root_key" != 1 ]] && dep="system-install-root-key"
  queue submit system-install-daemon --after-success "$dep" --reason "install bashqueues system daemon" -- bash "$work_dir/install-daemon.sh" "$src_dir" "$prefix"
fi
if [[ "$with_remote_listener" == 1 ]]; then
  queue submit system-install-remote-listener-policy --after-success system-install-core --reason "install remote listener policy files" -- bash "$work_dir/install-remote-listener-policy.sh" "$src_dir" "$prefix"
  queue submit system-install-remote-listener-service --after-success system-install-remote-listener-policy --reason "install remote listener systemd service" -- bash "$work_dir/install-remote-listener-service.sh" "$src_dir" "$prefix"
  queue submit system-install-remote-listener-verify --after-success system-install-remote-listener-service --reason "verify remote listener installation" -- bash "$work_dir/install-remote-listener-verify.sh" "$prefix"
fi

installer_failed_jobs() {
  find "$install_queue/failed" "$install_queue/pol_block" "$install_queue/interrupted" -type f -name '*.job' 2>/dev/null || true
}
installer_pending_jobs_count() {
  find "$install_queue/pending" -type f -name '*.job' 2>/dev/null | wc -l | tr -d '[:space:]'
}
installer_fail_if_any_job_failed() {
  if installer_failed_jobs | grep -q .; then
    echo "install-system.sh: one or more dogfood installation jobs failed" >&2
    installer_failed_jobs >&2 || true
    find "$install_queue/logs" -maxdepth 1 -type f -print -exec sh -c 'echo "### $1"; case "$1" in *.gz) gzip -cd "$1" 2>/dev/null | tail -80 ;; *) tail -80 "$1" ;; esac' _ {} \; >&2 || true
    exit 1
  fi
}

# Drain the isolated installer queue.  Dependency jobs intentionally use stable
# one-shot names and --after-success; each foreground run may reveal the next
# dependency level, so keep running until no pending installer jobs remain.
max_install_queue_passes=20
for ((install_queue_pass=1; install_queue_pass<=max_install_queue_passes; install_queue_pass++)); do
  pending_before="$(installer_pending_jobs_count)"
  [[ "$pending_before" -gt 0 ]] || break
  queue run
  installer_fail_if_any_job_failed
  pending_after="$(installer_pending_jobs_count)"
  [[ "$pending_after" -gt 0 ]] || break
done

remaining_pending="$(installer_pending_jobs_count)"
if [[ "$remaining_pending" -gt 0 ]]; then
  echo "install-system.sh: dogfood installation queue did not drain; pending jobs remain: $remaining_pending" >&2
  find "$install_queue/pending" -type f -name '*.job' -print >&2 || true
  find "$install_queue/logs" -maxdepth 1 -type f -print -exec tail -80 {} \; >&2 || true
  exit 1
fi

installer_fail_if_any_job_failed

if [[ "$with_remote_listener" == 1 ]]; then
  remote_policy_dir="/etc/bashqueues/policies.d/remote-queue"
  for required_remote_policy in     "$remote_policy_dir/remote-management.env"     "$remote_policy_dir/acl.tsv"     "$remote_policy_dir/clients.tsv"; do
    if [[ ! -f "$required_remote_policy" ]]; then
      echo "install-system.sh: remote listener policy file was not installed: $required_remote_policy" >&2
      exit 1
    fi
  done
fi

if [[ "$with_remote_listener" == 1 ]]; then
  remote_listener_status="$(cat <<'REMOTE_DONE'
  installed; policy files copied under:
    /etc/bashqueues/policies.d/remote-queue/

  Expected files:
    /etc/bashqueues/policies.d/remote-queue/remote-management.env
    /etc/bashqueues/policies.d/remote-queue/acl.tsv
    /etc/bashqueues/policies.d/remote-queue/clients.tsv

  Example source files:
    policies.d/remote-queue/remote-management.env.example
    policies.d/remote-queue/acl.example.tsv
    policies.d/remote-queue/clients.example.tsv

  Check service:
    systemctl status bashqueues-remote-management.service
REMOTE_DONE
)"
else
  remote_listener_status="  not installed; rerun with --with-remote-listener to enable"
fi

cat <<DONE
System installation complete.

Interactive shells:
  source /etc/profile.d/bashqueues.sh

Non-interactive wrapper:
  $bin_dir/queue version

Shared policies:
  queue policies list
  queue policy explain default

Cron bridge:
  $([[ "$with_cron" == 1 ]] && echo "installed; check: systemctl status bashqueues-cron.timer" || echo "not installed; rerun with --with-cron to enable")

System daemon:
  $([[ "$with_daemon" == 1 ]] && echo "installed; check: systemctl status bashqueues-daemon.service" || echo "not installed; rerun with --with-daemon to enable")

Remote queue management listener:
$remote_listener_status
DONE

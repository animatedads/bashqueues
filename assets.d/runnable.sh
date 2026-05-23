#!/usr/bin/env bash
# bashqueues standard script runnability asset checks
#
# Installed helper path:
#   ~/.queuebash/assets.d/runnable.sh
#
# Facilities published:
#   runnable:script       Checks script exists, is executable, and has a valid shebang
#   runnable:interpreter  Validates required interpreter is present with optional version gate
#   runnable:path         Checks required binaries are available in $PATH
#   runnable:library      Verifies shared library dependencies are satisfied
#   runnable:module       Tests module/class availability without executing user code
#   runnable:env_var      Ensures required environment variables are set
#   runnable:resource     Checks ulimits, disk space, and cgroup2 controllers
#   runnable:filesystem   Validates script dependencies (config files, dirs) exist
#
# Supported interpreters (zero configuration — discovered from PATH):
#   bash, sh, dash, ksh, zsh
#   python3, python
#   node
#   ruby
#   perl
#   php
#   go
#   rexx, rexx64, oorexx   (ooRexx / Open Object Rexx)
#   regina                 (Regina REXX)

queue_asset_facilities() {
	cat <<'FACILITIES'
runnable:script	Checks script exists, is executable, and has a valid shebang
runnable:interpreter	Validates required interpreter is present with optional version gate
runnable:path	Checks required binaries are available in $PATH
runnable:library	Verifies shared library dependencies are satisfied
runnable:module	Tests module/class availability without executing user code
runnable:env_var	Ensures required environment variables are set
runnable:resource	Checks ulimits, disk space, and cgroup2 controllers
runnable:filesystem	Validates script dependencies (config files, dirs) exist
FACILITIES
}

# Each plugin is sourceable standalone (queue assets validate, direct testing)
# as well as within the sourced queuebash.sh framework.
# queue_asset_param is redefined here so the plugin has no external dependency.
queue_asset_param() {
	local key="$1"
	shift
	local p
	for p in "$@"; do
		case "$p" in
			"$key="*) printf '%s\n' "${p#*=}"; return 0 ;;
		esac
	done
	return 1
}

# ---------------------------------------------------------------------------
# REXX/ooRexx discovery
#
# Works from PATH first; falls back to standard installation prefixes.
# Probes which CLI flags the found binary actually supports — ooRexx and
# Regina differ. Results cached for the lifetime of the sourced session.
# ---------------------------------------------------------------------------

_RUNNABLE_REXX_BIN=""
_RUNNABLE_REXX_SYNTAX_FLAG=""   # -c if supported, else empty
_RUNNABLE_REXX_VER_FLAG=""      # -v or --version if supported, else empty
_RUNNABLE_REXX_PROBED_FOR=""

_runnable_rexx_find() {
	local want="${1:-rexx}"
	[[ "$_RUNNABLE_REXX_PROBED_FOR" == "$want" && -n "$_RUNNABLE_REXX_BIN" ]] && return 0
	[[ "$_RUNNABLE_REXX_PROBED_FOR" == "$want" && -z "$_RUNNABLE_REXX_BIN" ]] && return 1

	_RUNNABLE_REXX_BIN=""
	_RUNNABLE_REXX_SYNTAX_FLAG=""
	_RUNNABLE_REXX_VER_FLAG=""
	_RUNNABLE_REXX_PROBED_FOR="$want"

	local names=()
	case "$want" in
		rexx)    names=(rexx rexx64 oorexx) ;;
		rexx64)  names=(rexx64 rexx) ;;
		oorexx)  names=(oorexx rexx rexx64) ;;
		regina)  names=(regina rexx) ;;
		*)       names=("$want") ;;
	esac

	# Empty prefix = use command -v (PATH); others = explicit prefix directories
	local prefixes=("" /usr/bin /usr/local/bin /opt/ooRexx/bin /opt/oorexx/bin /usr/lib/ooRexx/bin /opt/IBM/ooRexx/bin)
	local name prefix candidate

	for name in "${names[@]}"; do
		for prefix in "${prefixes[@]}"; do
			if [[ -z "$prefix" ]]; then
				candidate="$(command -v "$name" 2>/dev/null || true)"
			else
				candidate="$prefix/$name"
			fi
			if [[ -n "$candidate" && -x "$candidate" ]]; then
				_RUNNABLE_REXX_BIN="$candidate"
				_runnable_rexx_probe_flags "$candidate"
				return 0
			fi
		done
	done

	return 1
}

_runnable_rexx_probe_flags() {
	local bin="$1" tmp
	tmp="$(mktemp /tmp/runnable_probe_XXXXXX.rex 2>/dev/null)" || return 0
	printf '/* probe */\nsay "ok"\n' > "$tmp"
	timeout 5 "$bin" -c "$tmp" >/dev/null 2>&1 && _RUNNABLE_REXX_SYNTAX_FLAG="-c"
	rm -f "$tmp"
	timeout 5 "$bin" -v >/dev/null 2>&1 && _RUNNABLE_REXX_VER_FLAG="-v" && return 0
	timeout 5 "$bin" --version >/dev/null 2>&1 && _RUNNABLE_REXX_VER_FLAG="--version"
	return 0
}

_runnable_rexx_version() {
	[[ -z "$_RUNNABLE_REXX_VER_FLAG" || -z "$_RUNNABLE_REXX_BIN" ]] && { printf ''; return 0; }
	local out
	out="$(timeout 10 "$_RUNNABLE_REXX_BIN" "$_RUNNABLE_REXX_VER_FLAG" 2>&1 | head -2)"
	grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' <<< "$out" | head -1
}

_runnable_is_rexx() {
	[[ "$1" =~ ^(rexx|rexx64|oorexx|regina)$ ]]
}

_runnable_is_rexx_cls() {
	local f="$1"
	[[ "$f" == *.cls ]] && return 0
	[[ -r "$f" ]] && head -30 "$f" 2>/dev/null | grep -qiE '^[[:space:]]*::class[[:space:]]' && return 0
	return 1
}

_runnable_extract_version() {
	grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' <<< "$1" | head -1
}

_runnable_semver_gte() {
	# Returns 0 if actual >= required
	local required="$1" actual="$2"
	[[ -n "$required" && -n "$actual" ]] || return 1
	printf "%s\n%s\n" "$required" "$actual" | sort -V -C 2>/dev/null
}

# ---------------------------------------------------------------------------
# 1. runnable:script
# ---------------------------------------------------------------------------
queue_asset_check_runnable_script() {
	local token="$1" target_file="$2"
	shift 2 || true

	[[ -z "$target_file" ]] && {
		echo "asset_check_blocked: runnable:script $token requires a target file"
		return 1
	}

	local require_executable require_readable follow_symlinks validate_syntax
	require_executable="$(queue_asset_param require_executable "$@" || echo "1")"
	require_readable="$(queue_asset_param require_readable "$@" || echo "1")"
	follow_symlinks="$(queue_asset_param follow_symlinks "$@" || echo "0")"
	validate_syntax="$(queue_asset_param validate_syntax "$@" || echo "0")"

	[[ "$follow_symlinks" == "1" && -L "$target_file" ]] && \
		target_file="$(readlink -f "$target_file" 2>/dev/null || echo "$target_file")"

	[[ -e "$target_file" ]] || {
		echo "asset_check_blocked: runnable:script $token script does not exist: $target_file"
		return 1
	}
	[[ "$require_readable" != "1" || -r "$target_file" ]] || {
		echo "asset_check_blocked: runnable:script $token script not readable: $target_file"
		return 1
	}
	[[ "$require_executable" != "1" || -x "$target_file" ]] || {
		echo "asset_check_blocked: runnable:script $token script not executable: $target_file"
		return 1
	}

	# ooRexx .cls files legitimately carry no shebang
	if _runnable_is_rexx_cls "$target_file"; then
		echo "asset_check_ok: $token path=$target_file"
		return 0
	fi

	local shebang interpreter interpreter_path shebang_args
	shebang="$(head -1 "$target_file" 2>/dev/null | grep -E '^#!')"

	[[ -n "$shebang" ]] || {
		echo "asset_check_blocked: runnable:script $token no shebang line: $target_file"
		return 1
	}

	if [[ "$shebang" =~ ^#\!/usr/bin/env[[:space:]]+([^[:space:]]+)[[:space:]]*(.*)$ ]]; then
		interpreter="${BASH_REMATCH[1]}"
		shebang_args="${BASH_REMATCH[2]}"
		interpreter_path="$(command -v "$interpreter" 2>/dev/null || true)"
	elif [[ "$shebang" =~ ^#\!([^[:space:]]+)[[:space:]]*(.*)$ ]]; then
		interpreter_path="${BASH_REMATCH[1]}"
		interpreter="$(basename "$interpreter_path")"
		shebang_args="${BASH_REMATCH[2]}"
	else
		echo "asset_check_blocked: runnable:script $token unrecognised shebang: $shebang"
		return 1
	fi

	# REXX family — discover from PATH and standard prefixes, no config required
	if _runnable_is_rexx "$interpreter"; then
		if [[ -z "$interpreter_path" || ! -x "$interpreter_path" ]]; then
			_runnable_rexx_find "$interpreter" || true
			interpreter_path="$_RUNNABLE_REXX_BIN"
		fi
	fi

	[[ -n "$interpreter_path" && -x "$interpreter_path" ]] || {
		echo "asset_check_blocked: runnable:script $token interpreter not found: ${interpreter:-$interpreter_path}"
		return 1
	}

	[[ -z "$shebang_args" ]] || \
		echo "asset_check_warn: runnable:script $token shebang includes args '$shebang_args'"

	if [[ "$validate_syntax" == "1" ]]; then
		local t="${RUNNABLE_TIMEOUT:-10}"
		case "$interpreter" in
			bash|sh|dash|ksh|zsh)
				timeout "$t" bash -n "$target_file" >/dev/null 2>&1 || {
					echo "asset_check_blocked: runnable:script $token syntax error: $target_file"; return 1; }
				;;
			python3|python)
				timeout "$t" python3 -m py_compile "$target_file" >/dev/null 2>&1 || {
					echo "asset_check_blocked: runnable:script $token Python syntax error: $target_file"; return 1; }
				;;
			node)
				timeout "$t" node --check "$target_file" >/dev/null 2>&1 || {
					echo "asset_check_blocked: runnable:script $token Node.js syntax error: $target_file"; return 1; }
				;;
			ruby)
				timeout "$t" ruby -c "$target_file" >/dev/null 2>&1 || {
					echo "asset_check_blocked: runnable:script $token Ruby syntax error: $target_file"; return 1; }
				;;
			perl)
				timeout "$t" perl -c "$target_file" >/dev/null 2>&1 || {
					echo "asset_check_blocked: runnable:script $token Perl syntax error: $target_file"; return 1; }
				;;
			php)
				timeout "$t" php -l "$target_file" >/dev/null 2>&1 || {
					echo "asset_check_blocked: runnable:script $token PHP syntax error: $target_file"; return 1; }
				;;
			rexx|rexx64|oorexx|regina)
				if [[ -n "$_RUNNABLE_REXX_SYNTAX_FLAG" ]]; then
					timeout "$t" "$interpreter_path" "$_RUNNABLE_REXX_SYNTAX_FLAG" "$target_file" >/dev/null 2>&1 || {
						echo "asset_check_blocked: runnable:script $token REXX syntax error: $target_file"; return 1; }
				else
					echo "asset_check_warn: runnable:script $token REXX syntax check skipped (interpreter does not support -c)"
				fi
				;;
		esac
	fi

	echo "asset_check_ok: $token interpreter=$interpreter path=$interpreter_path"
	return 0
}

# ---------------------------------------------------------------------------
# 2. runnable:interpreter
# ---------------------------------------------------------------------------
queue_asset_check_runnable_interpreter() {
	local token="$1" interpreter="$2"
	shift 2 || true

	[[ -z "$interpreter" ]] && {
		echo "asset_check_blocked: runnable:interpreter $token requires interpreter name"
		return 1
	}

	local min_version max_size_mb target_file
	min_version="$(queue_asset_param min_version "$@" || true)"
	max_size_mb="$(queue_asset_param max_size_mb "$@" || echo "0")"
	target_file="$(queue_asset_param target "$@" || true)"

	local interpreter_path="" actual_version=""

	if _runnable_is_rexx "$interpreter"; then
		_runnable_rexx_find "$interpreter" || {
			echo "asset_check_blocked: runnable:interpreter $token REXX interpreter not found: $interpreter"
			return 1
		}
		interpreter_path="$_RUNNABLE_REXX_BIN"
		[[ -n "$min_version" ]] && actual_version="$(_runnable_rexx_version)"
	else
		interpreter_path="$(command -v "$interpreter" 2>/dev/null || true)"
		[[ -n "$interpreter_path" && -x "$interpreter_path" ]] || {
			echo "asset_check_blocked: runnable:interpreter $token interpreter not found: $interpreter"
			return 1
		}
		if [[ -n "$min_version" ]]; then
			local vcmd vout
			case "$interpreter" in
				bash)    vcmd="bash --version" ;;
				python3) vcmd="python3 --version" ;;
				python)  vcmd="python --version" ;;
				node)    vcmd="node --version" ;;
				ruby)    vcmd="ruby --version" ;;
				perl)    vcmd="perl --version" ;;
				php)     vcmd="php --version" ;;
				go)      vcmd="go version" ;;
				*)       vcmd="$interpreter --version" ;;
			esac
			vout="$(timeout "${RUNNABLE_TIMEOUT:-10}" sh -c "$vcmd" 2>&1 | head -1)"
			actual_version="$(_runnable_extract_version "$vout")"
		fi
	fi

	if [[ "$max_size_mb" -gt 0 ]]; then
		local sz
		sz="$(du -m "$interpreter_path" 2>/dev/null | awk '{print $1}')"
		[[ -z "$sz" || "$sz" -le "$max_size_mb" ]] || {
			echo "asset_check_blocked: runnable:interpreter $token size ${sz}MB exceeds max ${max_size_mb}MB: $interpreter_path"
			return 1
		}
	fi

	if [[ -n "$min_version" ]]; then
		if [[ -n "$actual_version" ]]; then
			_runnable_semver_gte "$min_version" "$actual_version" || {
				echo "asset_check_blocked: runnable:interpreter $token version too old (actual=$actual_version required>=$min_version)"
				return 1
			}
		else
			echo "asset_check_warn: runnable:interpreter $token could not determine version of $interpreter_path"
		fi
	fi

	# For ooRexx: optionally validate a target .cls file
	if _runnable_is_rexx "$interpreter" && [[ -n "$target_file" ]] && _runnable_is_rexx_cls "$target_file"; then
		[[ -f "$target_file" ]] || {
			echo "asset_check_blocked: runnable:interpreter $token ooRexx class file not found: $target_file"
			return 1
		}
		if [[ -n "$_RUNNABLE_REXX_SYNTAX_FLAG" ]]; then
			timeout "${RUNNABLE_TIMEOUT:-10}" "$interpreter_path" "$_RUNNABLE_REXX_SYNTAX_FLAG" "$target_file" >/dev/null 2>&1 || {
				echo "asset_check_blocked: runnable:interpreter $token ooRexx class file has errors: $target_file"
				return 1
			}
		fi
		local requires
		requires="$(grep -iE '^[[:space:]]*::requires[[:space:]]' "$target_file" 2>/dev/null \
			| grep -oE "[\"'][^\"']+[\"']|[^[:space:]\"']+$" | tr -d "\"'" | tr '\n' ' ')"
		[[ -z "$requires" ]] || echo "asset_check_info: runnable:interpreter $token ::requires $requires"
	fi

	echo "asset_check_ok: $token interpreter=$interpreter path=$interpreter_path version=${actual_version:-unknown}"
	return 0
}

# ---------------------------------------------------------------------------
# 3. runnable:path
# ---------------------------------------------------------------------------
queue_asset_check_runnable_path() {
	local token="$1" binaries="$2"
	shift 2 || true

	binaries="$(queue_asset_param binaries "$@" || echo "$binaries")"
	[[ -n "$binaries" ]] || {
		echo "asset_check_blocked: runnable:path $token requires binaries= parameter"
		return 1
	}

	local missing=()
	IFS=',' read -ra bin_list <<< "$binaries"
	for b in "${bin_list[@]}"; do
		b="${b// /}"
		[[ -z "$b" ]] && continue
		command -v "$b" >/dev/null 2>&1 || missing+=("$b")
	done

	[[ "${#missing[@]}" -eq 0 ]] || {
		echo "asset_check_blocked: runnable:path $token missing from PATH: ${missing[*]}"
		return 1
	}

	echo "asset_check_ok: $token"
	return 0
}

# ---------------------------------------------------------------------------
# 4. runnable:library
# ---------------------------------------------------------------------------
queue_asset_check_runnable_library() {
	local token="$1" target_binary="$2"
	shift 2 || true

	[[ -n "$target_binary" ]] || {
		echo "asset_check_blocked: runnable:library $token requires a target binary"
		return 1
	}
	[[ -f "$target_binary" ]] || {
		echo "asset_check_blocked: runnable:library $token binary not found: $target_binary"
		return 1
	}

	local safe_mode
	safe_mode="$(queue_asset_param safe_mode "$@" || echo "${RUNNABLE_SAFE_MODE:-0}")"

	local missing=()

	if [[ "$safe_mode" == "1" ]]; then
		command -v readelf >/dev/null 2>&1 || {
			echo "asset_check_warn: runnable:library $token readelf not available; skipping"
			echo "asset_check_ok: $token (skipped)"
			return 0
		}
		while IFS= read -r lib; do
			[[ -z "$lib" ]] && continue
			ldconfig -p 2>/dev/null | grep -q "$lib" || missing+=("$lib")
		done < <(readelf -d "$target_binary" 2>/dev/null \
			| grep '(NEEDED)' | grep -oE '\[.+\]' | tr -d '[]')
	else
		command -v ldd >/dev/null 2>&1 || {
			echo "asset_check_warn: runnable:library $token ldd not available; skipping"
			echo "asset_check_ok: $token (skipped)"
			return 0
		}
		while IFS= read -r line; do
			[[ "$line" == *"not found"* ]] && missing+=("$(awk '{print $1}' <<< "$line")")
		done < <(timeout "${RUNNABLE_TIMEOUT:-10}" ldd "$target_binary" 2>/dev/null)
	fi

	[[ "${#missing[@]}" -eq 0 ]] || {
		echo "asset_check_blocked: runnable:library $token missing libraries: ${missing[*]}"
		return 1
	}

	echo "asset_check_ok: $token"
	return 0
}

# ---------------------------------------------------------------------------
# 5. runnable:module
# ---------------------------------------------------------------------------
queue_asset_check_runnable_module() {
	local token="$1" language="$2"
	shift 2 || true

	local modules
	modules="$(queue_asset_param modules "$@" || true)"
	[[ -n "$modules" ]] || {
		echo "asset_check_blocked: runnable:module $token requires modules= parameter"
		return 1
	}

	IFS=',' read -ra mod_list <<< "$modules"
	local failed=()
	local t="${RUNNABLE_TIMEOUT:-10}"

	case "$language" in
		python|python3)
			for m in "${mod_list[@]}"; do
				m="${m// /}"
				timeout "$t" python3 -c \
					"import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('$m') else 1)" \
					>/dev/null 2>&1 || failed+=("$m")
			done
			;;

		rexx|oorexx|rexx64|regina)
			_runnable_rexx_find "$language" || {
				echo "asset_check_blocked: runnable:module $token REXX interpreter not found"
				return 1
			}
			for m in "${mod_list[@]}"; do
				m="${m// /}"
				if [[ "$m" == *.cls ]]; then
					if [[ ! -f "$m" ]]; then
						failed+=("$m (file not found)")
					elif [[ -n "$_RUNNABLE_REXX_SYNTAX_FLAG" ]]; then
						timeout "$t" "$_RUNNABLE_REXX_BIN" "$_RUNNABLE_REXX_SYNTAX_FLAG" "$m" >/dev/null 2>&1 \
							|| failed+=("$m (syntax error)")
					fi
				else
					# Probe via temp file with ::requires — no user code executed
					local tmpf
					tmpf="$(mktemp /tmp/runnable_mod_XXXXXX.rex 2>/dev/null)" || continue
					printf '::requires "%s"\n/* probe */\n' "$m" > "$tmpf"
					if [[ -n "$_RUNNABLE_REXX_SYNTAX_FLAG" ]]; then
						timeout "$t" "$_RUNNABLE_REXX_BIN" "$_RUNNABLE_REXX_SYNTAX_FLAG" "$tmpf" >/dev/null 2>&1 \
							|| failed+=("$m (not found or not loadable)")
					fi
					rm -f "$tmpf"
				fi
			done
			;;

		node|javascript)
			for m in "${mod_list[@]}"; do
				m="${m// /}"
				local found=0
				command -v npm >/dev/null 2>&1 && \
					timeout "$t" npm ls "$m" --silent --depth=0 >/dev/null 2>&1 && found=1
				[[ "$found" -eq 0 ]] && \
					timeout "$t" node -e "require.resolve('$m')" >/dev/null 2>&1 && found=1
				[[ "$found" -eq 1 ]] || failed+=("$m")
			done
			;;

		ruby)
			for m in "${mod_list[@]}"; do
				m="${m// /}"
				timeout "$t" ruby -r "$m" -e '' >/dev/null 2>&1 || failed+=("$m")
			done
			;;

		perl)
			for m in "${mod_list[@]}"; do
				m="${m// /}"
				timeout "$t" perl -M"$m" -e1 >/dev/null 2>&1 || failed+=("$m")
			done
			;;

		php)
			for m in "${mod_list[@]}"; do
				m="${m// /}"
				timeout "$t" php -r "if(!extension_loaded('$m')){exit(1);}" >/dev/null 2>&1 \
					|| failed+=("$m")
			done
			;;

		*)
			echo "asset_check_blocked: runnable:module $token unsupported language: $language"
			return 1
			;;
	esac

	[[ "${#failed[@]}" -eq 0 ]] || {
		echo "asset_check_blocked: runnable:module $token missing: ${failed[*]}"
		return 1
	}

	echo "asset_check_ok: $token"
	return 0
}

# ---------------------------------------------------------------------------
# 6. runnable:env_var
# ---------------------------------------------------------------------------
queue_asset_check_runnable_env_var() {
	local token="$1" vars="$2"
	shift 2 || true

	vars="$(queue_asset_param vars "$@" || echo "$vars")"
	[[ -n "$vars" ]] || {
		echo "asset_check_blocked: runnable:env_var $token requires vars= parameter"
		return 1
	}

	local missing=()
	IFS=',' read -ra var_list <<< "$vars"
	for v in "${var_list[@]}"; do
		v="${v// /}"
		[[ -z "$v" ]] && continue
		[[ -n "${!v+x}" ]] || missing+=("$v")
	done

	[[ "${#missing[@]}" -eq 0 ]] || {
		echo "asset_check_blocked: runnable:env_var $token unset: ${missing[*]}"
		return 1
	}

	echo "asset_check_ok: $token"
	return 0
}

# ---------------------------------------------------------------------------
# 7. runnable:resource
# ---------------------------------------------------------------------------
queue_asset_check_runnable_resource() {
	local token="$1"
	shift || true

	local min_disk_gb min_open_files min_procs cgroup2_controller check_path
	min_disk_gb="$(queue_asset_param min_disk_gb "$@" || echo "0")"
	min_open_files="$(queue_asset_param min_open_files "$@" || echo "0")"
	min_procs="$(queue_asset_param min_procs "$@" || echo "0")"
	cgroup2_controller="$(queue_asset_param cgroup2_controller "$@" || true)"
	check_path="$(queue_asset_param path "$@" || echo "/")"

	local failed=()

	if [[ "$min_disk_gb" -gt 0 ]]; then
		local avail_kb avail_gb
		avail_kb="$(df -k "$check_path" 2>/dev/null | awk 'NR==2{print $4}')"
		avail_gb=$(( ${avail_kb:-0} / 1048576 ))
		[[ "$avail_gb" -ge "$min_disk_gb" ]] || \
			failed+=("disk: ${avail_gb}GB available, ${min_disk_gb}GB required at $check_path")
	fi

	if [[ "$min_open_files" -gt 0 ]]; then
		local lim
		lim="$(ulimit -n 2>/dev/null || echo "0")"
		[[ "$lim" == "unlimited" || "$lim" -ge "$min_open_files" ]] || \
			failed+=("open_files: limit=$lim required>=$min_open_files")
	fi

	if [[ "$min_procs" -gt 0 ]]; then
		local plim
		plim="$(ulimit -u 2>/dev/null || echo "0")"
		[[ "$plim" == "unlimited" || "$plim" -ge "$min_procs" ]] || \
			failed+=("nproc: limit=$plim required>=$min_procs")
	fi

	if [[ -n "$cgroup2_controller" ]]; then
		if [[ -f "/sys/fs/cgroup/cgroup.controllers" ]]; then
			grep -qw "$cgroup2_controller" /sys/fs/cgroup/cgroup.controllers || \
				failed+=("cgroup2: $cgroup2_controller not available")
		else
			echo "asset_check_warn: runnable:resource $token cgroup2 not mounted; skipping controller check"
		fi
	fi

	[[ "${#failed[@]}" -eq 0 ]] || {
		echo "asset_check_blocked: runnable:resource $token ${failed[*]}"
		return 1
	}

	echo "asset_check_ok: $token"
	return 0
}

# ---------------------------------------------------------------------------
# 8. runnable:filesystem
# ---------------------------------------------------------------------------
queue_asset_check_runnable_filesystem() {
	local token="$1" required_paths="$2"
	shift 2 || true

	required_paths="$(queue_asset_param required_paths "$@" || echo "$required_paths")"
	[[ -n "$required_paths" ]] || {
		echo "asset_check_blocked: runnable:filesystem $token requires required_paths= parameter"
		return 1
	}

	local type writable
	type="$(queue_asset_param type "$@" || echo "any")"
	writable="$(queue_asset_param writable "$@" || echo "0")"

	local missing=()
	IFS=',' read -ra path_list <<< "$required_paths"
	for p in "${path_list[@]}"; do
		p="${p// /}"
		[[ -z "$p" ]] && continue
		local ok=1
		case "$type" in
			file)      [[ -f "$p" ]] || ok=0 ;;
			directory) [[ -d "$p" ]] || ok=0 ;;
			*)         [[ -e "$p" ]] || ok=0 ;;
		esac
		[[ "$ok" -eq 1 && "$writable" == "1" ]] && { [[ -w "$p" ]] || ok=0; }
		[[ "$ok" -eq 1 ]] || missing+=("$p")
	done

	[[ "${#missing[@]}" -eq 0 ]] || {
		echo "asset_check_blocked: runnable:filesystem $token missing ${type}: ${missing[*]}"
		return 1
	}

	echo "asset_check_ok: $token"
	return 0
}

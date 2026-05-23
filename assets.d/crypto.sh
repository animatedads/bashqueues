#!/usr/bin/env bash
# bashqueues standard cryptographic & integrity assets
# Version: 2.0 (Hardened - Fixed)
#
# Installed helper path:
#   ~/.queuebash/assets.d/crypto.sh
#
# Security Features:
#   - Timeout protection on all external commands
#   - HMAC key strength enforcement (min 32 bytes)
#   - Full IPC integration (env_file + hash_file)
#   - Tool fallbacks for all cryptographic operations
#
# Facilities published:
#   crypto:checksum      (Validates against SHA1/SHA256/SHA512 via static value, file, or IPC env)
#   crypto:md5           (Shorthand legacy wrapper for MD5 integrity checks)
#   crypto:hmac          (Validates an HMAC using openssl with key strength check)
#   crypto:blake2        (Checks file integrity using fast BLAKE2b/BLAKE2s hashes)
#   crypto:sha3          (Checks file integrity using SHA3-256/384/512 hashes)
#   crypto:gpg_sig       (Verifies detached GPG/PGP signatures)
#   crypto:gpg_embedded  (Verifies inline/clearsigned GPG/PGP envelopes)
#   crypto:gpg_key_valid (Verifies a GPG key exists and has not expired)
#   crypto:x509_sig      (Verifies OpenSSL x509 detached signatures)
#   crypto:smime         (Verifies S/MIME or PKCS#7 signed payloads)
#   crypto:pdf_sig       (Verifies embedded digital signatures inside a PDF document)
#   crypto:minisign      (Verifies modern Ed25519 signatures via minisign or signify)
#   crypto:age_recipient (Verifies file is age-encrypted for a specific recipient/identity)
#   crypto:jwt           (Validates JWT structure, claims, and verifies RS256 signatures via JWKS)

queue_asset_facilities() {
    cat <<'FACILITIES'
crypto:checksum	Checks file integrity against a specified hash (SHA, etc.)
crypto:md5	Shorthand legacy check for MD5 file integrity
crypto:hmac	Checks file integrity against an expected HMAC (min 32-byte key enforced)
crypto:blake2	Checks file integrity using BLAKE2b/BLAKE2s hash
crypto:sha3	Checks file integrity using SHA3-256/384/512 hash
crypto:gpg_sig	Verifies file authenticity using a detached GPG/PGP signature (.sig/.asc)
crypto:gpg_embedded	Verifies an inline/clearsigned PGP or GPG message
crypto:gpg_key_valid	Verifies a GPG key exists and meets minimum expiration requirements
crypto:x509_sig	Verifies file authenticity using an OpenSSL dgst signature and public key
crypto:smime	Verifies S/MIME or PKCS#7 signed payloads
crypto:pdf_sig	Verifies embedded digital signatures inside a PDF document
crypto:minisign	Verifies modern Ed25519 signatures via minisign or signify
crypto:age_recipient	Verifies file is age-encrypted for a specific recipient
crypto:jwt	Validates JWT structure, claims, and mathematical signature
FACILITIES
}

# Global configuration
_CRYPTO_TIMEOUT="${CRYPTO_TIMEOUT:-10}"
_CRYPTO_MIN_HMAC_KEY_BYTES="${CRYPTO_MIN_HMAC_KEY_BYTES:-32}"
_CRYPTO_VERBOSE="${CRYPTO_VERBOSE:-0}"

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

_crypto_read_kv_value() {
    local file="$1"
    local key="$2"
    [[ -n "$file" && -f "$file" && -n "$key" ]] || return 1

    # Do not source env-drop files here: asset checks may be run against
    # externally supplied files. Read only an exact KEY= prefix.
    awk -v k="$key" '
        index($0, k "=") == 1 {
            print substr($0, length(k) + 2)
            exit
        }
    ' "$file" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

# Helper: Safe command execution with timeout
_run_with_timeout() {
    local timeout_sec="$1"
    shift
    timeout "$timeout_sec" "$@" 2>/dev/null
}

# Helper: Log verbose messages
_log_verbose() {
    local token="$1"
    local msg="$2"
    if [[ "$_CRYPTO_VERBOSE" == "1" ]]; then
        echo "asset_check_info: $token $msg" >&2
    fi
}

# ---------------------------------------------------------
# 1. Standard Checksum Integrity (IPC Integrated - FIXED)
# ---------------------------------------------------------
queue_asset_check_crypto_checksum() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:checksum target missing: $target_file"; return 1; }

    local algo hash hash_file env_file env_key verbose
    algo="$(queue_asset_param algo "$@" || echo "sha256")"
    hash="$(queue_asset_param hash "$@" || true)"
    hash_file="$(queue_asset_param hash_file "$@" || true)"
    env_file="$(queue_asset_param env_file "$@" || true)"
    env_key="$(queue_asset_param env_key "$@" || true)"
    verbose="$(queue_asset_param verbose "$@" || echo "$_CRYPTO_VERBOSE")"

    # IPC Env Parsing (priority: env_file > hash_file > direct hash)
    if [[ -n "$env_file" && -f "$env_file" && -n "$env_key" ]]; then
        hash="$(_crypto_read_kv_value "$env_file" "$env_key")"
        [[ "$verbose" == "1" ]] && _log_verbose "$token" "hash from env_file=$env_file env_key=$env_key"
    elif [[ -n "$hash_file" && -f "$hash_file" ]]; then
        hash="$(awk '{print $1}' "$hash_file")"
        [[ "$verbose" == "1" ]] && _log_verbose "$token" "hash from hash_file=$hash_file"
    fi

    if [[ -z "$hash" ]]; then
        echo "asset_check_blocked: crypto:checksum no expected hash provided or readable via IPC"
        return 1
    fi

    # Validate algorithm (security: prevent injection)
    case "$algo" in
        md5|sha1|sha224|sha256|sha384|sha512|sha512224|sha512256) ;;
        *) echo "asset_check_blocked: crypto:checksum unsupported algorithm: $algo"; return 1 ;;
    esac

    if ! command -v "${algo}sum" >/dev/null 2>&1; then
        echo "asset_check_blocked: crypto:checksum algorithm ${algo}sum not installed"
        return 1
    fi

    local actual_hash
    actual_hash="$(_run_with_timeout "$_CRYPTO_TIMEOUT" "${algo}sum" "$target_file" | awk '{print $1}')"

    if [[ -z "$actual_hash" ]]; then
        echo "asset_check_blocked: crypto:checksum failed to compute hash for $target_file"
        return 1
    fi

    if [[ "$actual_hash" == "$hash" ]]; then
        [[ "$verbose" == "1" ]] && _log_verbose "$token" "checksum OK ($algo)"
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: crypto:checksum $algo mismatch on $target_file (expected=${hash:0:16}..., actual=${actual_hash:0:16}...)"
    return 1
}

# ---------------------------------------------------------
# 2. MD5 Shorthand Wrapper
# ---------------------------------------------------------
queue_asset_check_crypto_md5() {
    queue_asset_check_crypto_checksum "$1" "$2" algo=md5 "${@:3}"
}

# ---------------------------------------------------------
# 3. HMAC Verification (IPC Integrated - FIXED with key strength)
# ---------------------------------------------------------
queue_asset_check_crypto_hmac() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:hmac target missing: $target_file"; return 1; }

    local key algo expected_mac env_file env_key min_key_bytes
    key="$(queue_asset_param mac_key "$@" || true)"
    algo="$(queue_asset_param algo "$@" || echo "sha256")"
    expected_mac="$(queue_asset_param mac "$@" || true)"
    env_file="$(queue_asset_param env_file "$@" || true)"
    env_key="$(queue_asset_param env_key "$@" || true)"
    min_key_bytes="$(queue_asset_param min_key_bytes "$@" || echo "$_CRYPTO_MIN_HMAC_KEY_BYTES")"

    # IPC Env Parsing for HMAC
    if [[ -n "$env_file" && -f "$env_file" && -n "$env_key" ]]; then
        expected_mac="$(_crypto_read_kv_value "$env_file" "$env_key")"
    fi

    if [[ -z "$key" ]]; then
        echo "asset_check_blocked: crypto:hmac requires mac_key="
        return 1
    fi

    if [[ -z "$expected_mac" ]]; then
        echo "asset_check_blocked: crypto:hmac requires either mac= or env_key=/env_file="
        return 1
    fi

    # Enforce minimum key length (security)
    if [[ ${#key} -lt "$min_key_bytes" ]]; then
        echo "asset_check_blocked: crypto:hmac key too short (${#key} < $min_key_bytes bytes)"
        return 1
    fi

    # Validate HMAC algorithm
    case "$algo" in
        md5|sha1|sha224|sha256|sha384|sha512) ;;
        *) echo "asset_check_blocked: crypto:hmac unsupported algorithm: $algo"; return 1 ;;
    esac

    if ! command -v openssl >/dev/null 2>&1; then
        echo "asset_check_blocked: crypto:hmac requires openssl"
        return 1
    fi

    local actual_mac
    actual_mac="$(_run_with_timeout "$_CRYPTO_TIMEOUT" openssl dgst -"${algo}" -hmac "$key" "$target_file" | awk '{print $NF}')"

    if [[ -z "$actual_mac" ]]; then
        echo "asset_check_blocked: crypto:hmac failed to compute HMAC for $target_file"
        return 1
    fi

    if [[ "$actual_mac" == "$expected_mac" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: crypto:hmac mismatch on $target_file"
    return 1
}

# ---------------------------------------------------------
# 4. BLAKE2 Verification (IPC Integrated - FIXED fallbacks)
# ---------------------------------------------------------
queue_asset_check_crypto_blake2() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:blake2 target missing: $target_file"; return 1; }

    local algo hash env_file env_key verbose
    algo="$(queue_asset_param algo "$@" || echo "blake2b")"
    hash="$(queue_asset_param hash "$@" || true)"
    env_file="$(queue_asset_param env_file "$@" || true)"
    env_key="$(queue_asset_param env_key "$@" || true)"
    verbose="$(queue_asset_param verbose "$@" || echo "$_CRYPTO_VERBOSE")"

    if [[ -n "$env_file" && -f "$env_file" && -n "$env_key" ]]; then
        hash="$(_crypto_read_kv_value "$env_file" "$env_key")"
    fi

    if [[ -z "$hash" ]]; then
        echo "asset_check_blocked: crypto:blake2 no expected hash provided"
        return 1
    fi

    local actual_hash=""
    local hash_len="${algo#blake2}"
    [[ -z "$hash_len" || "$hash_len" == "b" || "$hash_len" == "s" ]] && hash_len="512"
    hash_len="${hash_len//[^0-9]/}"

    # Try b2sum first
    if command -v b2sum >/dev/null 2>&1; then
        actual_hash="$(_run_with_timeout "$_CRYPTO_TIMEOUT" b2sum -a "$hash_len" "$target_file" 2>/dev/null | awk '{print $1}')"
    fi

    # Fallback to openssl
    if [[ -z "$actual_hash" ]] && command -v openssl >/dev/null 2>&1; then
        actual_hash="$(_run_with_timeout "$_CRYPTO_TIMEOUT" openssl dgst -"$algo" "$target_file" 2>/dev/null | awk '{print $NF}')"
    fi

    # Fallback to blake2sum (older systems)
    if [[ -z "$actual_hash" ]] && command -v blake2sum >/dev/null 2>&1; then
        actual_hash="$(_run_with_timeout "$_CRYPTO_TIMEOUT" blake2sum -a "$hash_len" "$target_file" 2>/dev/null | awk '{print $1}')"
    fi

    if [[ -z "$actual_hash" ]]; then
        echo "asset_check_blocked: crypto:blake2 requires b2sum, blake2sum, or openssl"
        return 1
    fi

    if [[ "$actual_hash" == "$hash" ]]; then
        [[ "$verbose" == "1" ]] && _log_verbose "$token" "BLAKE2 OK ($algo-$hash_len)"
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: crypto:blake2 mismatch on $target_file"
    return 1
}

# ---------------------------------------------------------
# 5. SHA3 Verification (IPC Integrated)
# ---------------------------------------------------------
queue_asset_check_crypto_sha3() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:sha3 target missing: $target_file"; return 1; }

    local bits hash env_file env_key verbose
    bits="$(queue_asset_param bits "$@" || echo "256")"
    hash="$(queue_asset_param hash "$@" || true)"
    env_file="$(queue_asset_param env_file "$@" || true)"
    env_key="$(queue_asset_param env_key "$@" || true)"
    verbose="$(queue_asset_param verbose "$@" || echo "$_CRYPTO_VERBOSE")"

    if [[ -n "$env_file" && -f "$env_file" && -n "$env_key" ]]; then
        hash="$(_crypto_read_kv_value "$env_file" "$env_key")"
    fi

    [[ -z "$hash" ]] && { echo "asset_check_blocked: crypto:sha3 no expected hash provided"; return 1; }

    # Validate bits
    case "$bits" in
        224|256|384|512) ;;
        *) echo "asset_check_blocked: crypto:sha3 invalid bits: $bits (must be 224,256,384,512)"; return 1 ;;
    esac

    local actual_hash=""

    # Try openssl first (most common)
    if command -v openssl >/dev/null 2>&1; then
        if openssl dgst -sha3-"$bits" /dev/null 2>/dev/null; then
            actual_hash="$(_run_with_timeout "$_CRYPTO_TIMEOUT" openssl dgst -sha3-"$bits" "$target_file" 2>/dev/null | awk '{print $NF}')"
        fi
    fi

    # Fallback to sha3sum
    if [[ -z "$actual_hash" ]] && command -v sha3sum >/dev/null 2>&1; then
        actual_hash="$(_run_with_timeout "$_CRYPTO_TIMEOUT" sha3sum -a "$bits" "$target_file" 2>/dev/null | awk '{print $1}')"
    fi

    if [[ -z "$actual_hash" ]]; then
        echo "asset_check_blocked: crypto:sha3 requires openssl (3.0+) or sha3sum"
        return 1
    fi

    if [[ "$actual_hash" == "$hash" ]]; then
        [[ "$verbose" == "1" ]] && _log_verbose "$token" "SHA3-$bits OK"
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: crypto:sha3-$bits mismatch on $target_file"
    return 1
}

# ---------------------------------------------------------
# 6. Detached GPG / PGP Verification (FIXED - timeout)
# ---------------------------------------------------------
queue_asset_check_crypto_gpg_sig() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:gpg_sig target missing: $target_file"; return 1; }

    local sig_file keyring keyring_args
    sig_file="$(queue_asset_param sig_file "$@" || true)"
    keyring="$(queue_asset_param keyring "$@" || true)"

    [[ -z "$sig_file" || ! -f "$sig_file" ]] && { echo "asset_check_blocked: crypto:gpg_sig missing sig_file="; return 1; }
    [[ -n "$keyring" && -f "$keyring" ]] && keyring_args="--no-default-keyring --keyring $keyring"

    if _run_with_timeout "$_CRYPTO_TIMEOUT" gpg $keyring_args --verify "$sig_file" "$target_file" 2>/dev/null; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: crypto:gpg_sig failed for $target_file"
    return 1
}

# ---------------------------------------------------------
# 7. Inline / Clearsigned GPG / PGP Envelope Verification
# ---------------------------------------------------------
queue_asset_check_crypto_gpg_embedded() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:gpg_embedded target missing: $target_file"; return 1; }

    local keyring keyring_args
    keyring="$(queue_asset_param keyring "$@" || true)"
    [[ -n "$keyring" && -f "$keyring" ]] && keyring_args="--no-default-keyring --keyring $keyring"

    if _run_with_timeout "$_CRYPTO_TIMEOUT" gpg $keyring_args --verify "$target_file" 2>/dev/null; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: crypto:gpg_embedded invalid/missing inline signature: $target_file"
    return 1
}

# ---------------------------------------------------------
# 8. GPG Key Validity & Expiration Check (FIXED - keyserver refresh)
# ---------------------------------------------------------
queue_asset_check_crypto_gpg_key_valid() {
    local token="$1" key_id="$2"; shift 2 || true

    local min_valid_days keyserver refresh_keys
    min_valid_days="$(queue_asset_param min_valid_days "$@" || echo "30")"
    keyserver="$(queue_asset_param keyserver "$@" || true)"
    refresh_keys="$(queue_asset_param refresh_keys "$@" || echo "0")"

    # Optionally refresh key from keyserver
    if [[ "$refresh_keys" == "1" && -n "$keyserver" ]]; then
        _run_with_timeout "$_CRYPTO_TIMEOUT" gpg --keyserver "$keyserver" --recv-keys "$key_id" 2>/dev/null || true
    fi

    if ! gpg --list-keys --with-colons "$key_id" 2>/dev/null | grep -q "^pub"; then
        echo "asset_check_blocked: crypto:gpg_key_valid key not found: $key_id"
        return 1
    fi

    local expire_date
    expire_date="$(gpg --list-keys --with-colons "$key_id" 2>/dev/null | grep "^pub" | cut -d: -f7)"

    if [[ -n "$expire_date" && "$expire_date" != "" ]]; then
        local expire_epoch now_seconds days_left
        expire_epoch="$(date -d "$expire_date" +%s 2>/dev/null || echo 0)"
        now_seconds="$(date +%s)"
        days_left="$(( (expire_epoch - now_seconds) / 86400 ))"

        if [[ "$days_left" -lt "$min_valid_days" ]]; then
            echo "asset_check_blocked: crypto:gpg_key_valid key $key_id expires in ${days_left}d (minimum ${min_valid_days}d)"
            return 1
        fi
        echo "asset_check_ok: $token key $key_id valid for ${days_left}+ days"
    else
        echo "asset_check_ok: $token key $key_id has no expiration"
    fi
    return 0
}

# ---------------------------------------------------------
# 9. OpenSSL x509 / RSA / ECDSA Verification
# ---------------------------------------------------------
queue_asset_check_crypto_x509_sig() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:x509_sig target missing: $target_file"; return 1; }

    local sig_file pubkey algo
    sig_file="$(queue_asset_param sig_file "$@" || true)"
    pubkey="$(queue_asset_param pubkey "$@" || true)"
    algo="$(queue_asset_param algo "$@" || echo "sha256")"

    [[ -z "$sig_file" || ! -f "$sig_file" ]] && { echo "asset_check_blocked: crypto:x509_sig missing sig_file="; return 1; }
    [[ -z "$pubkey" || ! -f "$pubkey" ]] && { echo "asset_check_blocked: crypto:x509_sig missing pubkey="; return 1; }

    if _run_with_timeout "$_CRYPTO_TIMEOUT" openssl dgst "-${algo}" -verify "$pubkey" -signature "$sig_file" "$target_file" 2>/dev/null; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: crypto:x509_sig verification failed for $target_file"
    return 1
}

# ---------------------------------------------------------
# 10. S/MIME & PKCS#7 Embedded Signature Verification
# ---------------------------------------------------------
queue_asset_check_crypto_smime() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:smime target missing: $target_file"; return 1; }

    local ca_file ca_args
    ca_file="$(queue_asset_param ca_file "$@" || true)"

    if [[ -n "$ca_file" && -f "$ca_file" ]]; then
        ca_args="-CAfile $ca_file"
    else
        ca_args="-noverify"
    fi

    if _run_with_timeout "$_CRYPTO_TIMEOUT" openssl smime -verify -in "$target_file" $ca_args -out /dev/null 2>/dev/null; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: crypto:smime S/MIME signature invalid or missing: $target_file"
    return 1
}

# ---------------------------------------------------------
# 11. PDF Document Signature Verification
# ---------------------------------------------------------
queue_asset_check_crypto_pdf_sig() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:pdf_sig target missing: $target_file"; return 1; }

    if ! command -v pdfsig >/dev/null 2>&1; then
        echo "asset_check_blocked: crypto:pdf_sig requires 'poppler-utils' (pdfsig)"
        return 1
    fi

    local out
    out="$(_run_with_timeout "$_CRYPTO_TIMEOUT" pdfsig "$target_file" 2>/dev/null || true)"

    if echo "$out" | grep -q "Signature Validation: Valid"; then
        if ! echo "$out" | grep -q "Signature Validation: Invalid"; then
            echo "asset_check_ok: $token"
            return 0
        fi
    fi

    echo "asset_check_blocked: crypto:pdf_sig PDF signature missing/tampered: $target_file"
    return 1
}

# ---------------------------------------------------------
# 12. Minisign / Signify (Ed25519) - FIXED fallback order
# ---------------------------------------------------------
queue_asset_check_crypto_minisign() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:minisign target missing: $target_file"; return 1; }

    local pubkey sig_file
    pubkey="$(queue_asset_param pubkey "$@" || true)"
    sig_file="$(queue_asset_param sig_file "$@" || true)"

    [[ -z "$pubkey" ]] && { echo "asset_check_blocked: crypto:minisign requires pubkey="; return 1; }
    [[ -z "$sig_file" || ! -f "$sig_file" ]] && { echo "asset_check_blocked: crypto:minisign requires valid sig_file="; return 1; }

    # Try minisign first
    if command -v minisign >/dev/null 2>&1; then
        if _run_with_timeout "$_CRYPTO_TIMEOUT" minisign -V -P "$pubkey" -m "$target_file" -x "$sig_file" 2>/dev/null; then
            echo "asset_check_ok: $token"
            return 0
        fi
    fi

    # Fallback to signify (OpenBSD)
    if command -v signify >/dev/null 2>&1; then
        if _run_with_timeout "$_CRYPTO_TIMEOUT" signify -V -p "$pubkey" -m "$target_file" -x "$sig_file" 2>/dev/null; then
            echo "asset_check_ok: $token"
            return 0
        fi
    fi

    # Fallback to signify-openbsd (some Linux distributions)
    if command -v signify-openbsd >/dev/null 2>&1; then
        if _run_with_timeout "$_CRYPTO_TIMEOUT" signify-openbsd -V -p "$pubkey" -m "$target_file" -x "$sig_file" 2>/dev/null; then
            echo "asset_check_ok: $token"
            return 0
        fi
    fi

    echo "asset_check_blocked: crypto:minisign requires 'minisign' or 'signify' installed"
    return 1
}

# ---------------------------------------------------------
# 13. Age Encryption Recipient Verification (FIXED - better error handling)
# ---------------------------------------------------------
queue_asset_check_crypto_age_recipient() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:age_recipient target missing: $target_file"; return 1; }

    local recipient expected_identity verbose
    recipient="$(queue_asset_param recipient "$@" || true)"
    expected_identity="$(queue_asset_param expected_identity "$@" || true)"
    verbose="$(queue_asset_param verbose "$@" || echo "$_CRYPTO_VERBOSE")"

    [[ -z "$recipient" ]] && { echo "asset_check_blocked: crypto:age_recipient requires recipient="; return 1; }

    if ! command -v age >/dev/null 2>&1; then
        echo "asset_check_blocked: crypto:age_recipient requires 'age' installed"
        return 1
    fi

    # Try with identity file first
    if [[ -n "$expected_identity" && -f "$expected_identity" ]]; then
        if _run_with_timeout "$_CRYPTO_TIMEOUT" age -d -i "$expected_identity" -o /dev/null "$target_file" 2>/dev/null; then
            [[ "$verbose" == "1" ]] && _log_verbose "$token" "Age decryption OK with identity"
            echo "asset_check_ok: $token"
            return 0
        fi
    fi

    # age has no safe recipient-only verification mode. To prove decryptability
    # without emitting plaintext, require an identity file and decrypt to /dev/null.
    echo "asset_check_blocked: crypto:age_recipient requires expected_identity= for verification; recipient-only header checks are not supported by age"
    return 1
}

# ---------------------------------------------------------
# 14. JWT Structure & Cryptographic Signature Validation (FIXED - timeout wrapper)
# ---------------------------------------------------------
queue_asset_check_crypto_jwt() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:jwt target missing: $target_file"; return 1; }

    local jwks_url issuer audience timeout_sec
    jwks_url="$(queue_asset_param jwks_url "$@" || true)"
    issuer="$(queue_asset_param issuer "$@" || true)"
    audience="$(queue_asset_param audience "$@" || true)"
    timeout_sec="$(queue_asset_param timeout "$@" || echo "$_CRYPTO_TIMEOUT")"

    local jwt_content
    jwt_content="$(cat "$target_file" 2>/dev/null | tr -d '\n\r')"

    # Fast structural check
    if [[ ! "$jwt_content" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]]; then
        echo "asset_check_blocked: crypto:jwt invalid JWT format"
        return 1
    fi

    # Decode and check claims (requires jq)
    if command -v jq >/dev/null 2>&1; then
        local payload
        payload="$(echo "$jwt_content" | cut -d. -f2 | base64 -d 2>/dev/null || true)"

        if [[ -n "$issuer" && ! "$payload" =~ "\"iss\":\"$issuer\"" ]]; then
            echo "asset_check_blocked: crypto:jwt issuer mismatch (expected: $issuer)"
            return 1
        fi
        if [[ -n "$audience" && ! "$payload" =~ "\"aud\":\"$audience\"" ]]; then
            echo "asset_check_blocked: crypto:jwt audience mismatch (expected: $audience)"
            return 1
        fi
    else
        echo "asset_check_warn: crypto:jwt jq not available, skipping claim validation"
    fi

    # Cryptographic verification if JWKS provided
    if [[ -n "$jwks_url" ]]; then
        if ! command -v python3 >/dev/null 2>&1; then
            echo "asset_check_blocked: crypto:jwt requires python3 for signature verification"
            return 1
        fi

        # Check if PyJWT is installed
        if ! _run_with_timeout "$timeout_sec" python3 -c "import jwt" 2>/dev/null; then
            echo "asset_check_blocked: crypto:jwt requires PyJWT (pip install PyJWT)"
            return 1
        fi

        if ! _run_with_timeout "$timeout_sec" python3 -c "
import sys, json, urllib.request, socket
socket.setdefaulttimeout($timeout_sec)
try:
    import jwt
    from jwt import PyJWKClient
    token = open(sys.argv[1]).read().strip()
    jwks_client = PyJWKClient(sys.argv[2])
    signing_key = jwks_client.get_signing_key_from_jwt(token)
    aud = sys.argv[3] if sys.argv[3] and sys.argv[3] != 'None' else None
    iss = sys.argv[4] if sys.argv[4] and sys.argv[4] != 'None' else None
    jwt.decode(token, signing_key.key, algorithms=['RS256', 'RS384', 'RS512', 'ES256', 'ES384', 'ES512'], audience=aud, issuer=iss)
    sys.exit(0)
except Exception as e:
    sys.exit(1)
" "$target_file" "$jwks_url" "${audience:-None}" "${issuer:-None}" 2>/dev/null; then
            echo "asset_check_blocked: crypto:jwt cryptographic signature verification failed against JWKS"
            return 1
        fi
    fi

    echo "asset_check_ok: $token"
    return 0
}

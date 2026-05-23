#!/usr/bin/env bash
# bashqueues standard cryptographic & integrity assets
#
# Installed helper path:
#   ~/.queuebash/assets.d/crypto.sh
#
# Facilities published:
#   crypto:checksum      (Validates against SHA1/SHA256/SHA512 via static value, file, or IPC env)
#   crypto:md5           (Shorthand legacy wrapper for MD5 integrity checks)
#   crypto:hmac          (Validates an HMAC using openssl)
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
crypto:hmac	Checks file integrity against an expected HMAC
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

# ---------------------------------------------------------
# 1. Standard Checksum Integrity (IPC Integrated)
# ---------------------------------------------------------
queue_asset_check_crypto_checksum() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:checksum target missing: $target_file"; return 1; }

    local algo hash hash_file env_file env_key
    algo="$(queue_asset_param algo "$@" || echo "sha256")"
    hash="$(queue_asset_param hash "$@" || true)"
    hash_file="$(queue_asset_param hash_file "$@" || true)"
    env_file="$(queue_asset_param env_file "$@" || true)"
    env_key="$(queue_asset_param env_key "$@" || true)"

    if [[ -n "$env_file" && -f "$env_file" && -n "$env_key" ]]; then
        hash="$(grep "^${env_key}=" "$env_file" | head -n 1 | cut -d= -f2- | tr -d '\"' | tr -d '\'')"
    elif [[ -n "$hash_file" && -f "$hash_file" ]]; then
        hash="$(awk '{print $1}' "$hash_file")"
    fi

    if [[ -z "$hash" ]]; then
        echo "asset_check_blocked: crypto:checksum no expected hash provided or readable via IPC"; return 1
    fi

    if ! command -v "${algo}sum" >/dev/null 2>&1; then
        echo "asset_check_blocked: crypto:checksum algorithm ${algo}sum not installed"; return 1
    fi

    local actual_hash
    actual_hash="$("${algo}sum" "$target_file" | awk '{print $1}')"

    if [[ "$actual_hash" == "$hash" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: crypto:checksum $algo mismatch on $target_file"
    return 1
}

# ---------------------------------------------------------
# 2. MD5 Shorthand Wrapper
# ---------------------------------------------------------
queue_asset_check_crypto_md5() {
    queue_asset_check_crypto_checksum "$1" "$2" algo=md5 "$@"
}

# ---------------------------------------------------------
# 3. HMAC Verification (IPC Integrated)
# ---------------------------------------------------------
queue_asset_check_crypto_hmac() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:hmac target missing: $target_file"; return 1; }

    local key algo expected_mac env_file env_key
    key="$(queue_asset_param mac_key "$@" || true)"
    algo="$(queue_asset_param algo "$@" || echo "sha256")"
    expected_mac="$(queue_asset_param mac "$@" || true)"
    env_file="$(queue_asset_param env_file "$@" || true)"
    env_key="$(queue_asset_param env_key "$@" || true)"

    if [[ -n "$env_file" && -f "$env_file" && -n "$env_key" ]]; then
        expected_mac="$(grep "^${env_key}=" "$env_file" | head -n 1 | cut -d= -f2- | tr -d '\"' | tr -d '\'')"
    fi

    if [[ -z "$key" || -z "$expected_mac" ]]; then
        echo "asset_check_blocked: crypto:hmac requires mac_key= and either mac= or env_key=/env_file="; return 1
    fi

    local actual_mac
    actual_mac="$(openssl dgst -"${algo}" -hmac "$key" "$target_file" | awk '{print $NF}')"

    if [[ "$actual_mac" == "$expected_mac" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: crypto:hmac mismatch on $target_file"
    return 1
}

# ---------------------------------------------------------
# 4. BLAKE2 Verification (IPC Integrated)
# ---------------------------------------------------------
queue_asset_check_crypto_blake2() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:blake2 target missing: $target_file"; return 1; }

    local algo hash env_file env_key
    algo="$(queue_asset_param algo "$@" || echo "blake2b")"
    hash="$(queue_asset_param hash "$@" || true)"
    env_file="$(queue_asset_param env_file "$@" || true)"
    env_key="$(queue_asset_param env_key "$@" || true)"

    if [[ -n "$env_file" && -f "$env_file" && -n "$env_key" ]]; then
        hash="$(grep "^${env_key}=" "$env_file" | head -n 1 | cut -d= -f2- | tr -d '\"' | tr -d '\'')"
    fi

    if [[ -z "$hash" ]]; then
        echo "asset_check_blocked: crypto:blake2 no expected hash provided"; return 1
    fi

    local actual_hash
    if command -v b2sum >/dev/null 2>&1; then
        actual_hash="$(b2sum -a "${algo#blake2}" "$target_file" 2>/dev/null | awk '{print $1}')"
    elif command -v openssl >/dev/null 2>&1; then
        actual_hash="$(openssl dgst -"$algo" "$target_file" 2>/dev/null | awk '{print $NF}')"
    else
        echo "asset_check_blocked: crypto:blake2 requires b2sum or openssl"; return 1
    fi

    if [[ "$actual_hash" == "$hash" ]]; then
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

    local bits hash env_file env_key
    bits="$(queue_asset_param bits "$@" || echo "256")"
    hash="$(queue_asset_param hash "$@" || true)"
    env_file="$(queue_asset_param env_file "$@" || true)"
    env_key="$(queue_asset_param env_key "$@" || true)"

    if [[ -n "$env_file" && -f "$env_file" && -n "$env_key" ]]; then
        hash="$(grep "^${env_key}=" "$env_file" | head -n 1 | cut -d= -f2- | tr -d '\"' | tr -d '\'')"
    fi

    [[ -z "$hash" ]] && { echo "asset_check_blocked: crypto:sha3 no expected hash provided"; return 1; }

    local actual_hash
    if command -v openssl >/dev/null 2>&1 && openssl dgst -sha3-"$bits" /dev/null 2>/dev/null; then
        actual_hash="$(openssl dgst -sha3-"$bits" "$target_file" | awk '{print $NF}')"
    elif command -v sha3sum >/dev/null 2>&1; then
        actual_hash="$(sha3sum -a "$bits" "$target_file" | awk '{print $1}')"
    else
        echo "asset_check_blocked: crypto:sha3 requires openssl (3.0+) or sha3sum"; return 1
    fi

    if [[ "$actual_hash" == "$hash" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: crypto:sha3-$bits mismatch on $target_file"
    return 1
}

# ---------------------------------------------------------
# 6. Detached GPG / PGP Verification
# ---------------------------------------------------------
queue_asset_check_crypto_gpg_sig() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:gpg_sig target missing: $target_file"; return 1; }

    local sig_file keyring keyring_args
    sig_file="$(queue_asset_param sig_file "$@" || true)"
    keyring="$(queue_asset_param keyring "$@" || true)"

    [[ -z "$sig_file" || ! -f "$sig_file" ]] && { echo "asset_check_blocked: crypto:gpg_sig missing sig_file="; return 1; }
    [[ -n "$keyring" && -f "$keyring" ]] && keyring_args="--no-default-keyring --keyring $keyring"

    if gpg $keyring_args --verify "$sig_file" "$target_file" >/dev/null 2>&1; then
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

    if gpg $keyring_args --verify "$target_file" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: crypto:gpg_embedded invalid/missing inline signature: $target_file"
    return 1
}

# ---------------------------------------------------------
# 8. GPG Key Validity & Expiration Check
# ---------------------------------------------------------
queue_asset_check_crypto_gpg_key_valid() {
    local token="$1" key_id="$2"; shift 2 || true

    local min_valid_days
    min_valid_days="$(queue_asset_param min_valid_days "$@" || echo "30")"

    if ! gpg --list-keys --with-colons "$key_id" 2>/dev/null | grep -q "^pub"; then
        echo "asset_check_blocked: crypto:gpg_key_valid key not found: $key_id"
        return 1
    fi

    local expire_date
    expire_date="$(gpg --list-keys --with-colons "$key_id" 2>/dev/null | grep "^pub" | cut -d: -f7)"

    if [[ -n "$expire_date" ]]; then
        local expire_epoch expire_seconds now_seconds days_left
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

    if openssl dgst "-${algo}" -verify "$pubkey" -signature "$sig_file" "$target_file" >/dev/null 2>&1; then
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

    if openssl smime -verify -in "$target_file" $ca_args -out /dev/null >/dev/null 2>&1; then
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
        echo "asset_check_blocked: crypto:pdf_sig requires 'poppler-utils' (pdfsig)"; return 1
    fi

    local out
    out="$(pdfsig "$target_file" 2>/dev/null)"

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
# 12. Minisign / Signify (Ed25519)
# ---------------------------------------------------------
queue_asset_check_crypto_minisign() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:minisign target missing: $target_file"; return 1; }

    local pubkey sig_file
    pubkey="$(queue_asset_param pubkey "$@" || true)"
    sig_file="$(queue_asset_param sig_file "$@" || true)"

    [[ -z "$pubkey" ]] && { echo "asset_check_blocked: crypto:minisign requires pubkey="; return 1; }
    [[ -z "$sig_file" || ! -f "$sig_file" ]] && { echo "asset_check_blocked: crypto:minisign requires valid sig_file="; return 1; }

    if command -v minisign >/dev/null 2>&1; then
        minisign -V -P "$pubkey" -m "$target_file" -x "$sig_file" >/dev/null 2>&1 && { echo "asset_check_ok: $token"; return 0; }
    elif command -v signify >/dev/null 2>&1; then
        signify -V -p "$pubkey" -m "$target_file" -x "$sig_file" >/dev/null 2>&1 && { echo "asset_check_ok: $token"; return 0; }
    else
        echo "asset_check_blocked: crypto:minisign requires 'minisign' or 'signify' installed"; return 1
    fi

    echo "asset_check_blocked: crypto:minisign Ed25519 verification failed for $target_file"
    return 1
}

# ---------------------------------------------------------
# 13. Age Encryption Recipient Verification
# ---------------------------------------------------------
queue_asset_check_crypto_age_recipient() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:age_recipient target missing: $target_file"; return 1; }

    local recipient expected_identity
    recipient="$(queue_asset_param recipient "$@" || true)"
    expected_identity="$(queue_asset_param expected_identity "$@" || true)"

    [[ -z "$recipient" ]] && { echo "asset_check_blocked: crypto:age_recipient requires recipient="; return 1; }
    command -v age >/dev/null 2>&1 || { echo "asset_check_blocked: crypto:age_recipient requires 'age' installed"; return 1; }

    if [[ -n "$expected_identity" && -f "$expected_identity" ]]; then
        if age -d -i "$expected_identity" -o /dev/null "$target_file" 2>/dev/null; then
            echo "asset_check_ok: $token"
            return 0
        fi
    else
        if age --decrypt --recipient "$recipient" -o /dev/null "$target_file" 2>/dev/null; then
            echo "asset_check_ok: $token"
            return 0
        fi
    fi

    echo "asset_check_blocked: crypto:age_recipient file not decryptable for $recipient"
    return 1
}

# ---------------------------------------------------------
# 14. JWT Structure & Cryptographic Signature Validation
# ---------------------------------------------------------
queue_asset_check_crypto_jwt() {
    local token="$1" target_file="$2"; shift 2 || true
    [[ ! -f "$target_file" ]] && { echo "asset_check_blocked: crypto:jwt target missing: $target_file"; return 1; }

    local jwks_url issuer audience
    jwks_url="$(queue_asset_param jwks_url "$@" || true)"
    issuer="$(queue_asset_param issuer "$@" || true)"
    audience="$(queue_asset_param audience "$@" || true)"

    local jwt_content
    jwt_content="$(cat "$target_file" 2>/dev/null || true)"
    if [[ ! "$jwt_content" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]]; then
        echo "asset_check_blocked: crypto:jwt invalid JWT format"
        return 1
    fi

    command -v jq >/dev/null 2>&1 || { echo "asset_check_blocked: crypto:jwt requires jq"; return 1; }
    local payload
    payload="$(echo "$jwt_content" | cut -d. -f2 | base64 -d 2>/dev/null)"

    if [[ -n "$issuer" && ! "$payload" =~ "\"iss\":\"$issuer\"" ]]; then
        echo "asset_check_blocked: crypto:jwt issuer mismatch (expected: $issuer)"
        return 1
    fi
    if [[ -n "$audience" && ! "$payload" =~ "\"aud\":\"$audience\"" ]]; then
        echo "asset_check_blocked: crypto:jwt audience mismatch (expected: $audience)"
        return 1
    fi

    if [[ -n "$jwks_url" ]]; then
        if ! command -v python3 >/dev/null 2>&1; then
            echo "asset_check_blocked: crypto:jwt requires python3 for signature verification"
            return 1
        fi

        if ! python3 -c "
import sys, json, urllib.request, socket
socket.setdefaulttimeout(10)
try:
    import jwt
    token = open(sys.argv[1]).read().strip()
    jwks_client = jwt.PyJWKClient(sys.argv[2])
    signing_key = jwks_client.get_signing_key_from_jwt(token)
    aud = sys.argv[3] if sys.argv[3] else None
    iss = sys.argv[4] if sys.argv[4] else None
    jwt.decode(token, signing_key.key, algorithms=['RS256'], audience=aud, issuer=iss)
    sys.exit(0)
except Exception as e:
    sys.exit(1)
" "$target_file" "$jwks_url" "$audience" "$issuer" >/dev/null 2>&1; then
            echo "asset_check_blocked: crypto:jwt cryptographic signature verification failed against JWKS"
            return 1
        fi
    fi

    echo "asset_check_ok: $token"
    return 0
}

#!/usr/bin/env bash
# bashqueues standard database asset checks
#
# Installed helper path:
#   ~/.queuebash/assets.d/db.sh
#
# Facilities published:
#   db:postgres_connect
#   db:mysql_connect
#   db:sqlite_accessible
#   db:redis_connect
#   db:mongodb_connect

queue_asset_facilities() {
    cat <<'FACILITIES'
db:postgres_connect	Checks PostgreSQL connectivity with optional query validation
db:mysql_connect	Checks MySQL/MariaDB connectivity with optional query validation
db:sqlite_accessible	Checks SQLite database file is accessible and valid
db:redis_connect	Checks Redis server connectivity and optional key existence
db:mongodb_connect	Checks MongoDB server connectivity with optional database/collection validation
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

queue_asset_check_db_postgres_connect() {
    local token="$1"
    local endpoint="$2"
    shift 2 || true

    local host port user password db_name timeout query result

    host="$(queue_asset_param host "$@" || echo 'localhost')"
    port="$(queue_asset_param port "$@" || echo 5432)"
    user="$(queue_asset_param user "$@" || echo 'postgres')"
    password="$(queue_asset_param password "$@" || echo '')"
    db_name="$(queue_asset_param db_name "$@" || echo 'postgres')"
    timeout="$(queue_asset_param timeout "$@" || echo 5)"
    query="$(queue_asset_param query "$@" || echo 'SELECT 1')"

    # Parse endpoint if provided in host:port format
    if [[ -n "$endpoint" && "$endpoint" == *:* ]]; then
        host="${endpoint%:*}"
        port="${endpoint##*:}"
    elif [[ -n "$endpoint" ]]; then
        host="$endpoint"
    fi

    # Validate numeric port
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: db:postgres_connect invalid port number: $port"
        return 1
    fi

    # Build psql command
    local psql_opts="-h $host -p $port -U $user -d $db_name -w --no-password -c \"$query\" -t"

    if [[ -n "$password" ]]; then
        PGPASSWORD="$password" timeout "$timeout" psql $psql_opts >/dev/null 2>&1
    else
        timeout "$timeout" psql $psql_opts >/dev/null 2>&1
    fi

    if [[ $? -eq 0 ]]; then
        echo "asset_check_ok: db:postgres_connect $host:$port/$db_name"
        return 0
    fi

    echo "asset_check_blocked: db:postgres_connect failed to connect to $host:$port/$db_name (timeout=${timeout}s)"
    return 1
}

queue_asset_check_db_mysql_connect() {
    local token="$1"
    local endpoint="$2"
    shift 2 || true

    local host port user password db_name timeout query

    host="$(queue_asset_param host "$@" || echo 'localhost')"
    port="$(queue_asset_param port "$@" || echo 3306)"
    user="$(queue_asset_param user "$@" || echo 'root')"
    password="$(queue_asset_param password "$@" || echo '')"
    db_name="$(queue_asset_param db_name "$@" || echo 'mysql')"
    timeout="$(queue_asset_param timeout "$@" || echo 5)"
    query="$(queue_asset_param query "$@" || echo 'SELECT 1')"

    # Parse endpoint if provided in host:port format
    if [[ -n "$endpoint" && "$endpoint" == *:* ]]; then
        host="${endpoint%:*}"
        port="${endpoint##*:}"
    elif [[ -n "$endpoint" ]]; then
        host="$endpoint"
    fi

    # Validate numeric port
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: db:mysql_connect invalid port number: $port"
        return 1
    fi

    # Build mysql command
    local mysql_opts="-h $host -P $port -u $user -D $db_name"

    if [[ -n "$password" ]]; then
        mysql_opts="$mysql_opts -p$password"
    fi

    timeout "$timeout" mysql $mysql_opts -e "$query" >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        echo "asset_check_ok: db:mysql_connect $host:$port/$db_name"
        return 0
    fi

    echo "asset_check_blocked: db:mysql_connect failed to connect to $host:$port/$db_name (timeout=${timeout}s)"
    return 1
}

queue_asset_check_db_sqlite_accessible() {
    local token="$1"
    local db_path="$2"
    shift 2 || true

    local timeout query

    timeout="$(queue_asset_param timeout "$@" || echo 5)"
    query="$(queue_asset_param query "$@" || echo 'SELECT 1')"

    if [[ -z "$db_path" ]]; then
        echo "asset_check_blocked: db:sqlite_accessible requires database path parameter"
        return 1
    fi

    if [[ ! -f "$db_path" ]]; then
        echo "asset_check_blocked: db:sqlite_accessible database file does not exist: $db_path"
        return 1
    fi

    if [[ ! -r "$db_path" ]]; then
        echo "asset_check_blocked: db:sqlite_accessible database file is not readable: $db_path"
        return 1
    fi

    # Test sqlite3 connectivity with timeout
    timeout "$timeout" sqlite3 "$db_path" "$query" >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        echo "asset_check_ok: db:sqlite_accessible $db_path"
        return 0
    fi

    echo "asset_check_blocked: db:sqlite_accessible failed to query database: $db_path (timeout=${timeout}s)"
    return 1
}

queue_asset_check_db_redis_connect() {
    local token="$1"
    local endpoint="$2"
    shift 2 || true

    local host port password timeout key_check require_key

    host="$(queue_asset_param host "$@" || echo 'localhost')"
    port="$(queue_asset_param port "$@" || echo 6379)"
    password="$(queue_asset_param password "$@" || echo '')"
    timeout="$(queue_asset_param timeout "$@" || echo 5)"
    require_key="$(queue_asset_param require_key "$@" || echo '')"

    # Parse endpoint if provided in host:port format
    if [[ -n "$endpoint" && "$endpoint" == *:* ]]; then
        host="${endpoint%:*}"
        port="${endpoint##*:}"
    elif [[ -n "$endpoint" ]]; then
        host="$endpoint"
    fi

    # Validate numeric port
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: db:redis_connect invalid port number: $port"
        return 1
    fi

    # Build redis-cli command
    local redis_opts="-h $host -p $port"
    if [[ -n "$password" ]]; then
        redis_opts="$redis_opts -a $password"
    fi

    # Test basic connectivity
    timeout "$timeout" redis-cli $redis_opts ping >/dev/null 2>&1

    if [[ $? -ne 0 ]]; then
        echo "asset_check_blocked: db:redis_connect failed to connect to $host:$port (timeout=${timeout}s)"
        return 1
    fi

    # Check for required key if specified
    if [[ -n "$require_key" ]]; then
        timeout "$timeout" redis-cli $redis_opts EXISTS "$require_key" >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            echo "asset_check_blocked: db:redis_connect required key does not exist: $require_key"
            return 1
        fi
    fi

    echo "asset_check_ok: db:redis_connect $host:$port"
    return 0
}

queue_asset_check_db_mongodb_connect() {
    local token="$1"
    local uri="$2"
    shift 2 || true

    local host port user password auth_db db_name timeout query

    host="$(queue_asset_param host "$@" || echo 'localhost')"
    port="$(queue_asset_param port "$@" || echo 27017)"
    user="$(queue_asset_param user "$@" || echo '')"
    password="$(queue_asset_param password "$@" || echo '')"
    auth_db="$(queue_asset_param auth_db "$@" || echo 'admin')"
    db_name="$(queue_asset_param db_name "$@" || echo 'test')"
    timeout="$(queue_asset_param timeout "$@" || echo 5)"
    query="$(queue_asset_param query "$@" || echo '{\"ping\": 1}')"

    # Parse URI if provided in mongodb://user:pass@host:port/db format
    if [[ -n "$uri" && "$uri" == mongodb://* ]]; then
        # Simple URI parsing - for complex URIs, recommend using mongosh directly
        uri="${uri#mongodb://}"
        if [[ "$uri" == *@* ]]; then
            local userpass="${uri%%@*}"
            user="${userpass%%:*}"
            password="${userpass##*:}"
            uri="${uri#*@}"
        fi
        host="${uri%%:*}"
        port="${uri##*:}"
        port="${port%%/*}"
        db_name="${uri##*/}"
    elif [[ -n "$uri" && "$uri" == *:* ]]; then
        host="${uri%:*}"
        port="${uri##*:}"
    elif [[ -n "$uri" ]]; then
        host="$uri"
    fi

    # Validate numeric port
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: db:mongodb_connect invalid port number: $port"
        return 1
    fi

    # Build mongosh connection string
    local mongosh_uri="mongodb://"
    if [[ -n "$user" && -n "$password" ]]; then
        mongosh_uri="${mongosh_uri}${user}:${password}@"
    fi
    mongosh_uri="${mongosh_uri}${host}:${port}/${db_name}"

    if [[ -n "$auth_db" && -n "$user" ]]; then
        mongosh_uri="${mongosh_uri}?authSource=${auth_db}"
    fi

    # Test connectivity using mongosh (or mongo for older versions)
    timeout "$timeout" mongosh "$mongosh_uri" --eval "db.adminCommand({ping: 1})" >/dev/null 2>&1

    # Fallback to older 'mongo' client if mongosh not available
    if [[ $? -ne 0 ]]; then
        timeout "$timeout" mongo "$mongosh_uri" --eval "db.adminCommand({ping: 1})" >/dev/null 2>&1
    fi

    if [[ $? -eq 0 ]]; then
        echo "asset_check_ok: db:mongodb_connect $host:$port/$db_name"
        return 0
    fi

    echo "asset_check_blocked: db:mongodb_connect failed to connect to $host:$port/$db_name (timeout=${timeout}s)"
    return 1
}

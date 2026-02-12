#!/usr/bin/env bash
set -euo pipefail

# MySQL 备份脚本（多环境）
# 用法:
#   ./mysql_backup.sh --user backup --host 127.0.0.1 --password secret --port 3306
#   ./mysql_backup.sh --user backup --socket /path/to/mysql.sock --password secret
#   ./mysql_backup.sh --env-name prod --user backup --host 10.0.0.10 --password secret
#   ./mysql_backup.sh --env-file .env.mysql --user backup --host 127.0.0.1 --password secret

# ====== 配置 ======
ENV_NAME="${ENV_NAME:-dev}"              # dev | staging | prod | custom
ENV_FILE="${ENV_FILE:-}"                # 可选环境变量文件
BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-$HOME/backups/mysql}"
BACKUP_MODE="${BACKUP_MODE:-per_db}"    # per_db | all_in_one
RETENTION_DAYS="${RETENTION_DAYS:-}"
COMPRESS="${COMPRESS:-gzip}"            # gzip | none

# 连接信息
MYSQL_HOST="${MYSQL_HOST:-}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
MYSQL_SOCKET="${MYSQL_SOCKET:-}"
MYSQL_SSL_OPTS="${MYSQL_SSL_OPTS:-}"    # 例如 "--ssl-mode=REQUIRED --ssl-ca=/path/ca.pem"

# 数据库选择
DB_LIST="${DB_LIST:-}"                  # 逗号分隔列表，留空=自动发现
EXCLUDE_DB="${EXCLUDE_DB:-}"            # 逗号分隔，排除列表

# 备份参数
DUMP_OPTS="${DUMP_OPTS:---single-transaction --routines --events --triggers --set-gtid-purged=OFF}"
MYSQL_EXTRA_OPTS="${MYSQL_EXTRA_OPTS:-}"

# ====== 工具函数 ======
log() { echo "[$(date +'%F %T')] $*"; }
SCRIPT_NAME="$(basename "$0")"

# 替换 usage 中的脚本名占位符
usage() {
  local out
  out="$(cat <<'EOF'
用法:
  __SCRIPT__ --user backup --host 127.0.0.1 --password secret --port 3306
  __SCRIPT__ --user backup --socket /path/to/mysql.sock --password secret
  __SCRIPT__ --env-name prod --user backup --host 10.0.0.10 --password secret
  __SCRIPT__ --env-file .env.mysql --user backup --host 127.0.0.1 --password secret

必填参数（其一）:
  1) --host + --user + --password
  2) --socket + --user + --password

可选参数:
  --env-name dev|staging|prod
  --env-file .env.mysql
  --backup-base-dir ~/backups/mysql
  --backup-mode per_db|all_in_one
  --retention-days 7
  --compress gzip|none
  --ssl-opts "--ssl-mode=REQUIRED --ssl-ca=/path/ca.pem"
  --db-list "db1,db2"
  --exclude-db "db1,db2"
  --dump-opts "--single-transaction --routines --events --triggers --set-gtid-purged=OFF"
EOF
)"
  echo "${out//__SCRIPT__/${SCRIPT_NAME}}"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# 参数解析（关键字参数，顺序无关）
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-name) ENV_NAME="${2:-}"; shift 2 ;;
    --env-file) ENV_FILE="${2:-}"; shift 2 ;;
    --backup-base-dir) BACKUP_BASE_DIR="${2:-}"; shift 2 ;;
    --backup-mode) BACKUP_MODE="${2:-}"; shift 2 ;;
    --retention-days) RETENTION_DAYS="${2:-}"; shift 2 ;;
    --compress) COMPRESS="${2:-}"; shift 2 ;;
    --host) MYSQL_HOST="${2:-}"; shift 2 ;;
    --port) MYSQL_PORT="${2:-}"; shift 2 ;;
    --user) MYSQL_USER="${2:-}"; shift 2 ;;
    --password) MYSQL_PASSWORD="${2:-}"; shift 2 ;;
    --password=*) MYSQL_PASSWORD="${1#*=}"; shift 1 ;;
    --socket) MYSQL_SOCKET="${2:-}"; shift 2 ;;
    --ssl-opts) MYSQL_SSL_OPTS="${2:-}"; shift 2 ;;
    --db-list) DB_LIST="${2:-}"; shift 2 ;;
    --exclude-db) EXCLUDE_DB="${2:-}"; shift 2 ;;
    --dump-opts) DUMP_OPTS="${2:-}"; shift 2 ;;
    --) shift; break ;;
    *) echo "❌ 未知参数: $1"; usage; exit 1 ;;
  esac
done

if [[ -n "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# 必要参数检查
if [[ -z "$MYSQL_USER" ]]; then
  echo "❌ 缺少必填参数: --user"
  usage
  exit 1
fi
if [[ -z "$MYSQL_PASSWORD" ]]; then
  echo "❌ 缺少必填参数: --password"
  usage
  exit 1
fi
if [[ -z "$MYSQL_HOST" && -z "$MYSQL_SOCKET" ]]; then
  echo "❌ 缺少必填参数: --host 或 --socket"
  usage
  exit 1
fi

# 多环境默认值（仅在未显式设置时生效）
if [[ -z "$RETENTION_DAYS" ]]; then
  case "$ENV_NAME" in
    dev) RETENTION_DAYS=3 ;;
    staging) RETENTION_DAYS=7 ;;
    prod) RETENTION_DAYS=14 ;;
    *) RETENTION_DAYS=7 ;;
  esac
fi

# 必要依赖
command -v mysql >/dev/null 2>&1 || { echo "❌ 未找到 mysql 客户端"; exit 1; }
command -v mysqldump >/dev/null 2>&1 || { echo "❌ 未找到 mysqldump"; exit 1; }

# 连接参数
MYSQL_ARGS=("-h" "$MYSQL_HOST" "-P" "$MYSQL_PORT" "-u" "$MYSQL_USER")
if [[ -n "$MYSQL_PASSWORD" ]]; then
  export MYSQL_PWD="$MYSQL_PASSWORD"
fi
if [[ -n "$MYSQL_SOCKET" ]]; then
  MYSQL_ARGS+=("--socket" "$MYSQL_SOCKET")
fi
if [[ -n "$MYSQL_SSL_OPTS" ]]; then
  # shellcheck disable=SC2206
  MYSQL_ARGS+=( $MYSQL_SSL_OPTS )
fi
if [[ -n "$MYSQL_EXTRA_OPTS" ]]; then
  # shellcheck disable=SC2206
  MYSQL_ARGS+=( $MYSQL_EXTRA_OPTS )
fi

# 自动发现数据库
if [[ -z "$DB_LIST" ]]; then
  DB_LIST=$(mysql "${MYSQL_ARGS[@]}" -N -e "SHOW DATABASES;")
  # 去掉尾部逗号
  DB_LIST=$(echo "$DB_LIST" | tr '\n' ',' | sed 's/,$//')
fi

# 排除列表
EXCLUDE_SET=""
if [[ -n "$EXCLUDE_DB" ]]; then
  EXCLUDE_SET=",${EXCLUDE_DB},"
fi

TIMESTAMP=$(date +'%F_%H%M%S')
TARGET_DIR="$BACKUP_BASE_DIR/$ENV_NAME/$TIMESTAMP"
mkdir -p "$TARGET_DIR"

log "开始备份: ENV=$ENV_NAME HOST=$MYSQL_HOST PORT=$MYSQL_PORT"

backup_one_db() {
  local db="$1"
  local out="$TARGET_DIR/${db}.sql"
  log "备份数据库: $db"
  mysqldump "${MYSQL_ARGS[@]}" $DUMP_OPTS "$db" > "$out"
  if [[ "$COMPRESS" == "gzip" ]]; then
    gzip -f "$out"
  fi
}

backup_all_in_one() {
  local out="$TARGET_DIR/all_databases.sql"
  log "备份全部数据库"
  mysqldump "${MYSQL_ARGS[@]}" $DUMP_OPTS --all-databases > "$out"
  if [[ "$COMPRESS" == "gzip" ]]; then
    gzip -f "$out"
  fi
}

if [[ "$BACKUP_MODE" == "all_in_one" ]]; then
  backup_all_in_one
else
  IFS=',' read -r -a DBS <<< "$DB_LIST"
  for db in "${DBS[@]}"; do
    db="$(echo "$db" | xargs)"
    [[ -z "$db" ]] && continue
    if [[ "$EXCLUDE_SET" == *",${db},"* ]]; then
      log "跳过数据库: $db"
      continue
    fi
    # 默认跳过系统库
    case "$db" in
      information_schema|performance_schema|mysql|sys) continue ;;
    esac
    backup_one_db "$db"
  done
fi

# 保留策略
log "清理 $RETENTION_DAYS 天前的备份"
find "$BACKUP_BASE_DIR/$ENV_NAME" -mindepth 1 -maxdepth 1 -type d -mtime "+$RETENTION_DAYS" -print0 | xargs -0r rm -rf

log "✅ 备份完成: $TARGET_DIR"
IP_ADDR=""
if hostname -I >/dev/null 2>&1; then
  IP_ADDR="$(hostname -I | awk '{print $1}')"
elif command -v ip >/dev/null 2>&1; then
  IP_ADDR="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1;i<=NF;i++) if ($i==\"src\") {print $(i+1); exit}}')"
elif command -v ipconfig >/dev/null 2>&1; then
  IP_ADDR="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi
if [[ -n "$IP_ADDR" ]]; then
  log "✅ 系统信息: IP地址=${IP_ADDR} 主机名=$(hostname)"
else
  log "✅ 系统信息: IP地址=<未知> 主机名=$(hostname)"
fi

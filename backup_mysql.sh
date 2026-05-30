#!/bin/bash

# ------------------- 配置 -------------------
LOGIN_PATH="mysql_backup"                # mysql_config_editor 配置名
DATABASES=("future_ana" "admin")         # 数据库列表
BACKUP_TMP_DIR="/tmp/mysql_backup"       # 临时目录
REMOTE_DIR="dev-mysql-backup"            # 百度网盘目录
RETENTION_DAYS=3

TODAY=$(date +"%Y%m%d")
THRESHOLD_DATE=$(date -d "${RETENTION_DAYS} days ago" +"%Y%m%d")

mkdir -p "$BACKUP_TMP_DIR"

# ------------------------------------------
# 备份单个数据库（备份 -> 上传 -> 立即删除本地）
# ------------------------------------------
backup_single_db() {
    local DB_NAME=$1
    local BACKUP_FILE="${BACKUP_TMP_DIR}/${DB_NAME}_${TODAY}.sql.gz"

    echo "========================================"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting backup of: $DB_NAME"
    echo "Backup file: $BACKUP_FILE"

    # 1. 导出并压缩
    mysqldump --login-path="$LOGIN_PATH" \
              --single-transaction \
              --routines \
              --triggers \
              "$DB_NAME" 2> >(grep -v "Using a password" >&2) | gzip > "$BACKUP_FILE"

    # 检查 mysqldump 是否成功（PIPESTATUS[0] 是 mysqldump 的退出码）
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "[ERROR] Backup failed for $DB_NAME - check MySQL login-path"
        return 1
    fi

    local FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "[SUCCESS] Backup created: $BACKUP_FILE (size: $FILE_SIZE)"

    # 2. 上传到百度网盘
    /usr/local/bin/bypy -s 100MB -r 5 upload "$BACKUP_FILE" "$REMOTE_DIR/"

    if [ $? -eq 0 ]; then
        echo "[SUCCESS] Uploaded to $REMOTE_DIR/"
        rm -f "$BACKUP_FILE"
        echo "[INFO] Deleted local temp file: $BACKUP_FILE"
    else
        echo "[ERROR] Upload failed for $DB_NAME, local file kept: $BACKUP_FILE"
        return 1
    fi
}

# ------------------------------------------
# 清理远程超过 3 天的备份（稳健版）
# ------------------------------------------
cleanup_remote_old() {
    echo "========================================"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaning old backups in $REMOTE_DIR"

    # 获取远程文件列表，并过滤出 .sql.gz 文件
    local tmp_file_list=$(mktemp)
    /usr/local/bin/bypy list "$REMOTE_DIR" 2>/dev/null | grep -E '\.sql\.gz$' > "$tmp_file_list"

    if [ ! -s "$tmp_file_list" ]; then
        echo "No .sql.gz files found in $REMOTE_DIR"
        rm -f "$tmp_file_list"
        return
    fi

    while IFS= read -r line; do
        # 提取文件名（最后一列，假设没有空格的文件名）
        local REMOTE_FILE=$(echo "$line" | awk '{print $NF}')
        if [[ "$REMOTE_FILE" =~ _([0-9]{8})\.sql\.gz$ ]]; then
            local FILE_DATE="${BASH_REMATCH[1]}"
            if [[ "$FILE_DATE" < "$THRESHOLD_DATE" ]]; then
                echo "Deleting old backup: $REMOTE_DIR/$REMOTE_FILE (date $FILE_DATE)"
                /usr/local/bin/bypy delete "$REMOTE_DIR/$REMOTE_FILE"
            else
                echo "Keeping: $REMOTE_FILE (date $FILE_DATE)"
            fi
        else
            echo "Skipping unexpected file: $REMOTE_FILE"
        fi
    done < "$tmp_file_list"

    rm -f "$tmp_file_list"
}

# ------------------------------------------
# 主流程
# ------------------------------------------
for DB in "${DATABASES[@]}"; do
    backup_single_db "$DB"
done

cleanup_remote_old

echo "========================================"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] MySQL backup finished."
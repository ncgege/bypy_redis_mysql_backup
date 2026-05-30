#!/bin/bash

# 本地 Redis 数据目录
LOCAL_DIR="/var/lib/redis"
REMOTE_DIR="bot-dev"

# 精确到秒的时间戳（格式：20260530_143052）
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
# 3天前的日期（仅日期部分，用于清理）
THRESHOLD=$(date -d "3 days ago" +"%Y%m%d")

upload_files() {
    for FILE in "$LOCAL_DIR"/*; do
        [ -f "$FILE" ] || continue
        FILENAME=$(basename "$FILE")
        if [[ "$FILENAME" == *.* ]]; then
            NAME="${FILENAME%.*}"
            EXT="${FILENAME##*.}"
            NEW_FILENAME="${NAME}_${TIMESTAMP}.${EXT}"
        else
            NEW_FILENAME="${FILENAME}_${TIMESTAMP}"
        fi
        /usr/local/bin/bypy upload "$FILE" "$REMOTE_DIR/$NEW_FILENAME"
        echo "$(date) - Uploaded $FILE as $REMOTE_DIR/$NEW_FILENAME" >> /var/log/redis_backup.log
    done
}

cleanup_old_backups() {
    echo "$(date) - Checking old backups in $REMOTE_DIR ..." >> /var/log/redis_backup.log
    REMOTE_FILES=$(/usr/local/bin/bypy list "$REMOTE_DIR" 2>/dev/null | awk '{print $NF}')
    for REMOTE_FILE in $REMOTE_FILES; do
        if [[ "$REMOTE_FILE" =~ _([0-9]{8})(_|\.) ]]; then
            FILE_DATE="${BASH_REMATCH[1]}"
            if [[ "$FILE_DATE" < "$THRESHOLD" ]]; then
                echo "$(date) - Deleting old backup: $REMOTE_DIR/$REMOTE_FILE" >> /var/log/redis_backup.log
                /usr/local/bin/bypy delete "$REMOTE_DIR/$REMOTE_FILE"
            fi
        fi
    done
}

upload_files
cleanup_old_backups
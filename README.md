markdown
# bypy_redis_mysql_backup

使用 `bypy` 将 Redis 和 MySQL 数据库自动备份到百度网盘。

## 📁 脚本列表

| 脚本 | 说明 |
| --- | --- |
| `backup_redis.sh` | 备份 Redis 数据（RDB 文件），支持秒级时间戳，保留最近 3 天 |
| `backup_mysql.sh` | 备份 MySQL 数据库（future_ana / admin），压缩后上传，保留最近 3 天 |

---

## 🚀 快速开始

### 1. 安装 bypy

```bash
pip3 install bypy
```
2. 授权百度网盘
```bash
bypy info
```
按提示打开链接 → 登录百度网盘 → 获取授权码 → 粘贴到终端

3. 配置 MySQL 登录（仅 MySQL 需要）

# 创建加密登录配置
```bash
mysql_config_editor set --login-path=mysql_backup --host=localhost --user=root --password
```
# 验证配置
```bash
mysql_config_editor print --login-path=mysql_backup
```
💡 如果提示 mysql_config_editor: command not found，请安装 mysql-client（如 apt install mysql-client）。

4. 修改脚本配置
根据您的环境修改以下变量：

Redis 脚本 (backup_redis.sh)

```bash
LOCAL_DIR="/var/lib/redis"    # Redis 数据目录
REMOTE_DIR="bot-dev"          # 百度网盘目标目录
MySQL 脚本 (backup_mysql.sh)
```
```bash
LOGIN_PATH="mysql_backup"           # mysql_config_editor 配置名
DATABASES=("future_ana" "admin")    # 要备份的数据库
REMOTE_DIR="dev-mysql-backup"       # 百度网盘目标目录
RETENTION_DAYS=3                    # 保留天数
```
5. 添加执行权限
```bash
chmod +x /home/backup/backup_redis.sh
chmod +x /home/backup/backup_mysql.sh
```
6. 配置 crontab 定时任务
```bash
crontab -e
```
添加以下内容：

# Redis 备份：每 5 分钟一次
*/5 * * * * /home/backup/backup_redis.sh >/dev/null 2>&1

# MySQL 备份：每天凌晨 2:00 执行一次
0 2 * * * /home/backup/backup_mysql.sh >/dev/null 2>&1
🔧 手动测试

# 测试 Redis 备份
```bash
/home/backup/backup_redis.sh
```
# 测试 MySQL 备份
```bash
/home/backup/backup_mysql.sh
```
📦 备份文件命名规则
脚本	文件名示例	说明
Redis	dump_20260530_143052.rdb	YYYYMMDD_HHMMSS，精确到秒
MySQL	future_ana_20260530.sql.gz	YYYYMMDD，压缩后上传
🗑️ 自动清理策略
Redis：保留最近 3 天 内所有秒级备份文件（同一天可能有多个）

MySQL：保留最近 3 天 每天一个压缩备份

超过保留天数的文件会被 bypy delete 自动删除（仅删除匹配命名规则的文件）

🐛 常见问题
Q1: 上传时出现 Slice MD5 mismatch 错误
解决方法：在 bypy upload 命令后添加 -s 100MB 参数（强制指定分片大小），或升级 bypy：

bash
pip3 install --upgrade bypy
Q2: MySQL 备份提示 Access denied (using password: YES)
解决方法：重新设置 mysql_config_editor，确保密码正确：

bash
mysql_config_editor set --login-path=mysql_backup --host=localhost --user=root --password
mysql --login-path=mysql_backup -e "SELECT 1"   # 测试连接
Q3: 临时文件 /tmp/mysql_backup/*.sql.gz 需要手动清理吗？
不需要。脚本上传成功后会自动删除当天生成的临时文件，不会占用磁盘空间。

Q4: 如何修改保留天数？
修改脚本中的 RETENTION_DAYS 变量即可。

📄 依赖
bypy (≥ 1.8.9)

mysqldump (MySQL 客户端)

redis (用于生成 RDB 快照，通常已随 Redis 安装)

gzip (通常系统自带)

📜 许可证
MIT

text

请将以上完整内容保存为 `README.md`，然后重新查看 GitHub 渲染效果，表格应该正常显示了。如果还有问题，请检查您的 Markdown 渲染器是否支持标准表格语法（GitHub 完全支持）。
# AgrisaleCL服务器端

## 快速开始

### 1. 创建虚拟环境（推荐，特别是 Ubuntu 24.04）

**注意：** Ubuntu 24.04 及更新版本需要使用虚拟环境，否则会报错 `externally-managed-environment`。

```bash
# 安装 python3-venv（如果还没安装）
sudo apt update
sudo apt install python3-venv python3-full -y

# 创建虚拟环境
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate

# 激活后，命令行前面会显示 (venv)
```

### 2. 安装依赖

```bash
# 确保虚拟环境已激活（命令行前有 (venv)）
# 升级 pip（可选但推荐）
pip install --upgrade pip

# 安装项目依赖
pip install -r requirements.txt
```

### 3. 创建数据库目录

```bash
# 在 server 目录下创建 data 目录
mkdir -p data
```

### 4. 配置环境变量（可选）

创建 `.env` 文件或设置环境变量：

```bash
# 数据库配置（路径相对于server目录）
export DB_PATH="data/agrisalecl.db"
export DB_MAX_CONNECTIONS=10
export DB_BUSY_TIMEOUT=5000

# JWT 密钥（生产环境必须更改）
export SECRET_KEY="your-secret-key-change-this-in-production"

# 服务器配置
export HOST="0.0.0.0"
export PORT=8000
```

### 5. 启动服务器

#### 方式一：使用启动脚本（推荐）

```bash
# 在 server 目录下
cd server

# 激活虚拟环境
source venv/bin/activate

# 运行启动脚本
chmod +x start.sh
./start.sh
```

启动脚本会自动：
- 检测并激活虚拟环境
- 切换到正确的目录
- 设置环境变量
- 启动服务器

#### 方式二：直接使用 uvicorn

**从项目根目录运行（server 的父目录）：**

```bash
# 确保在项目根目录（包含 server 目录的目录）
cd ..  # 如果当前在 server 目录，切换到父目录

# 激活虚拟环境
cd server
source venv/bin/activate
cd ..

# 启动服务器
python -m uvicorn server.main:app --host 0.0.0.0 --port 8000 --reload
```

### 6. 访问 API 文档

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## API 端点

### 认证相关
- `POST /api/auth/register` - 用户注册
- `POST /api/auth/login` - 用户登录
- `POST /api/auth/logout` - 用户登出
- `GET /api/auth/me` - 获取当前用户信息
- `POST /api/auth/refresh` - 刷新 Token
- `POST /api/auth/change-password` - 修改密码

### 用户状态
- `POST /api/users/heartbeat` - 更新心跳
- `GET /api/users/online` - 获取在线设备列表
- `GET /api/users/online/count` - 获取在线设备数量
- `POST /api/users/online/update-action` - 更新当前操作
- `POST /api/users/online/clear-action` - 清除当前操作

### 产品管理
- `GET /api/products` - 获取产品列表
- `GET /api/products/{id}` - 获取产品详情
- `POST /api/products` - 创建产品
- `PUT /api/products/{id}` - 更新产品
- `DELETE /api/products/{id}` - 删除产品
- `POST /api/products/{id}/stock` - 更新库存

### 采购管理
- `GET /api/purchases` - 获取采购记录列表
- `GET /api/purchases/{id}` - 获取采购记录详情
- `POST /api/purchases` - 创建采购记录
- `PUT /api/purchases/{id}` - 更新采购记录
- `DELETE /api/purchases/{id}` - 删除采购记录

### 销售管理
- `GET /api/sales` - 获取销售记录列表
- `GET /api/sales/{id}` - 获取销售记录详情
- `POST /api/sales` - 创建销售记录
- `PUT /api/sales/{id}` - 更新销售记录
- `DELETE /api/sales/{id}` - 删除销售记录

### 退货管理
- `GET /api/returns` - 获取退货记录列表
- `GET /api/returns/{id}` - 获取退货记录详情
- `POST /api/returns` - 创建退货记录
- `PUT /api/returns/{id}` - 更新退货记录
- `DELETE /api/returns/{id}` - 删除退货记录

### 客户管理
- `GET /api/customers` - 获取客户列表
- `GET /api/customers/all` - 获取所有客户
- `GET /api/customers/{id}` - 获取客户详情
- `POST /api/customers` - 创建客户
- `PUT /api/customers/{id}` - 更新客户
- `DELETE /api/customers/{id}` - 删除客户

### 供应商管理
- `GET /api/suppliers` - 获取供应商列表
- `GET /api/suppliers/all` - 获取所有供应商
- `GET /api/suppliers/{id}` - 获取供应商详情
- `POST /api/suppliers` - 创建供应商
- `PUT /api/suppliers/{id}` - 更新供应商
- `DELETE /api/suppliers/{id}` - 删除供应商

### 员工管理
- `GET /api/employees` - 获取员工列表
- `GET /api/employees/all` - 获取所有员工
- `GET /api/employees/{id}` - 获取员工详情
- `POST /api/employees` - 创建员工
- `PUT /api/employees/{id}` - 更新员工
- `DELETE /api/employees/{id}` - 删除员工

### 进账管理
- `GET /api/income` - 获取进账记录列表
- `GET /api/income/{id}` - 获取进账记录详情
- `POST /api/income` - 创建进账记录
- `PUT /api/income/{id}` - 更新进账记录
- `DELETE /api/income/{id}` - 删除进账记录

### 汇款管理
- `GET /api/remittance` - 获取汇款记录列表
- `GET /api/remittance/{id}` - 获取汇款记录详情
- `POST /api/remittance` - 创建汇款记录
- `PUT /api/remittance/{id}` - 更新汇款记录
- `DELETE /api/remittance/{id}` - 删除汇款记录

### 用户设置
- `GET /api/settings` - 获取用户设置
- `PUT /api/settings` - 更新用户设置
- `POST /api/settings/import-data` - 导入数据

## 系统端点

- `GET /` - API 信息
- `GET /health` - 健康检查
- `GET /api/info` - API 详细信息

## 特性

### 1. 数据安全
- JWT Token 认证
- 密码 bcrypt 加密
- 用户数据隔离（每个用户只能访问自己的数据）

### 2. 并发控制
- SQLite 连接池（支持 3-4 人并发）
- WAL 模式（Write-Ahead Logging）
- 乐观锁（防止并发冲突）
- 自动重试机制

### 3. 数据完整性
- 外键约束
- 事务支持
- 自动回滚

### 4. 错误处理
- 统一的错误响应格式
- 详细的错误日志
- 友好的错误消息

### 5. 性能优化
- 连接池管理
- 数据库索引
- 分页支持

## 生产环境部署

### 使用 systemd 服务（Linux）

#### 步骤 1：找到虚拟环境的 Python 路径

```bash
cd server
source venv/bin/activate
which python
# 会显示类似：/path/to/server/venv/bin/python
```

#### 步骤 2：创建 systemd 服务文件

```bash
sudo nano /etc/systemd/system/agrisalecl.service
```

**如果使用虚拟环境（推荐）：**

```ini
[Unit]
Description=AgrisaleCL API Server
After=network.target

[Service]
Type=simple
User=your-user
# 工作目录设置为项目根目录（server 的父目录）
WorkingDirectory=/path/to/project-root
Environment="PATH=/path/to/server/venv/bin:/usr/local/bin:/usr/bin:/bin"
# 使用相对路径（相对于server目录）
Environment="DB_PATH=data/agrisalecl.db"
Environment="SECRET_KEY=your-production-secret-key"
ExecStart=/path/to/server/venv/bin/python -m uvicorn server.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**如果不使用虚拟环境（不推荐）：**

```ini
[Unit]
Description=AgrisaleCL API Server
After=network.target

[Service]
Type=simple
User=your-user
# 工作目录设置为项目根目录（server 的父目录）
WorkingDirectory=/path/to/project-root
# 使用相对路径（相对于server目录）
Environment="DB_PATH=data/agrisalecl.db"
Environment="SECRET_KEY=your-production-secret-key"
ExecStart=/usr/bin/python3 -m uvicorn server.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**注意：** 
- 将 `/path/to/project-root` 替换为你的实际项目根目录路径（server 的父目录）
- 将 `/path/to/server/venv/bin/python` 替换为步骤 1 中获取的实际路径
- 将 `your-user` 替换为你的实际用户名

#### 步骤 3：启用并启动服务

```bash
sudo systemctl daemon-reload
sudo systemctl enable agrisalecl
sudo systemctl start agrisalecl
sudo systemctl status agrisalecl
```

### 使用 Nginx 反向代理

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

## 注意事项

1. **JWT 密钥**：生产环境必须更改 `SECRET_KEY`，使用强随机字符串
2. **数据库路径**：确保数据库目录有写权限
3. **并发连接数**：根据实际用户数调整 `DB_MAX_CONNECTIONS`
4. **日志**：生产环境建议配置日志轮转
5. **HTTPS**：生产环境建议使用 HTTPS

## 故障排查

### 数据库连接失败
- 检查数据库文件路径和权限
- 检查数据库目录是否存在

### 端口被占用
- 更改 `PORT` 环境变量
- 或使用 `lsof -i :8000` 查看占用进程

### 导入错误
- 确保已安装所有依赖：`pip install -r requirements.txt`（在虚拟环境中）
- 检查 Python 版本（需要 Python 3.8+）
- 确保虚拟环境已激活：`source venv/bin/activate`

### 虚拟环境相关问题

#### 问题：externally-managed-environment 错误

**原因：** Ubuntu 24.04 及更新版本不允许直接在系统 Python 中安装包。

**解决方法：** 使用虚拟环境（见"快速开始"第 1 步）。

#### 问题：找不到 uvicorn 命令

**原因：** 虚拟环境未激活或依赖未安装。

**解决方法：**
```bash
# 激活虚拟环境
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

# 使用 python -m uvicorn 而不是直接使用 uvicorn
python -m uvicorn server.main:app --host 0.0.0.0 --port 8000
```

#### 问题：systemd 服务启动失败

**原因：** 服务配置中使用了错误的 Python 路径。

**解决方法：**
1. 确认虚拟环境的 Python 路径：`which python`（在激活虚拟环境后）
2. 更新 systemd 服务文件中的 `ExecStart` 路径
3. 重新加载服务：`sudo systemctl daemon-reload`

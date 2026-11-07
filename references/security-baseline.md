# 审计、部署和收尾

只读检查发行版/架构/CPU 指令、CPU/RAM/Swap/磁盘、接口与路由、SSH known_hosts/独立指纹/认证方式/sshd Match 条件、systemd 单元和覆盖、实际进程使用的 Xray/sing-box/Hysteria 配置、监听、UFW/nftables/云防火墙、Nginx、TLS 链与期限、Certbot 版本/timer/hook、近期日志/OOM/备份。带宽与月度额度另核对服务商，不由本机推定。

preflight-audit.py 只给资源和服务摘要，不能代替上述完整审计。权限不足记 unknown；不为读取而装工具或改权限。配置、nginx -T、journal、环境和 argv 可能含密钥，捕获到受保护本地文件，仅输出脱敏字段/计数。

首次 SSH 通过独立可信渠道核对；指纹变化立即停止，服务商控制台等带外确认后备份 known_hosts 再更新。不能关闭 StrictHostKeyChecking，也不能删掉记录再当成首次连接。

部署计划列文件/服务/端口/diff/停机影响/恢复条件。备份二进制、配置、单元、权限/属主、Nginx、证书副本/hook、订阅及防火墙，验证可读和摘要后才改。备份仍是秘密。

每核心独立系统用户、无交互 shell；配置 600 或服务组 640、限制父目录遍历。systemd 设置适配核心的 Restart=on-failure、重启限制、NoNewPrivileges、最小能力/可写目录；低端口仅必要 CAP_NET_BIND_SERVICE，不默默回退 root。硬化逐项测试证书/UDP/数据文件读写。

只开放需要的端口/传输类型，保留管理通道，不清空旧防火墙。每步按官方二进制校验→候选校验→备份→原子更新→重载/重启→active/监听→真实请求执行；失败停止并恢复该步，不盲目重启全部服务。

收尾核对：SSH 密钥/密码认证、指纹、root 密码是否暴露/需轮换、Token、新旧订阅、Nginx access/error 日志及归档/journal/history 的敏感路径、Git 实际跟踪与忽略、.secrets/.runtime、临时证书/配置/PID/端口。Windows 用 NTFS ACL 核对权限；.gitignore 不会取消已跟踪文件。

只清理本次拥有且无用途的产物，保留回滚备份。轮换密码、关闭密码认证、撤销 Token、修改历史日志/管理端口需具体授权，先验证第二条管理会话。日志脱敏不使已泄露凭据恢复保密。报告不写真实服务器地址、指纹、UUID、密码、私钥或 Token。

## 凭据与日志收尾

- 扫描源码、文档、README、日志、journal、shell history、进程 argv 和 Git 历史中的 IP/UUID/密码/Token/私钥块；只报告文件/位置/类别，不回显值。
- 订阅 URL 只存 600 文件；curl 用 stdin 或受保护配置，不进入 argv；不截图、不转发、不使用公共转换服务。
- 旧凭据一旦在聊天、终端或日志中出现，按已泄露处理；轮换/撤销需批准，并先确认 SSH/控制台第二条管理通道可用。
- 备份仍然是秘密：限制权限/属主、必要时加密、设置保留周期；`.gitignore` 不会取消已跟踪文件的泄露。
- 服务用户不能写证书/私钥/配置目录；systemd 加固和文件权限逐项用实际进程验证，不只看 unit 文本。

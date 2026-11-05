# 证书与续期

合并 PEM 必须按实际版本验证，不假定所有实现支持。先隔离端口加载 fullchain+private key 同一文件并完成 TLS/代理请求，再迁移生产。历史版本见 validated-baseline.md。

1. 备份证书副本/配置/hook，核对 lineage、服务名、权限及热加载能力。无域名时重新核对 CA 的 IP 证书政策和 Certbot 支持。
2. 在目标目录创建受限临时文件并合并证书/私钥。分别用 openssl x509 -pubkey -noout 和 openssl pkey -pubout 提取公钥、转同一 DER 编码、比较 SHA256。检查所有退出码，不能让两份空输出相等蒙混通过；验证身份/期限/链。
3. 临时文件先设属主/权限，同一文件系统原子 mv；跨文件系统不保证原子。多个服务目标不是跨文件事务，失败需恢复已经替换的部分。
4. 根据实际版本 reload/restart，不凭经验假定热读取。检查 active、权限、对外提供证书和实际请求，失败恢复旧文件并重新加载。
5. 运行支持的 certbot renew --dry-run --run-deploy-hooks；先核对授权和 hook 副作用，可能重启生产，不能算只读。
6. 从受保护 Certbot 日志确认目标 hook 真正执行，记录脱敏退出状态、mtime、服务加载证据与握手；模拟续期成功不等于真实续期或业务成功。
7. 验证 timer、下次运行、短证书余量、失败告警，真实续期后再次核对提供的新证书。

hook 应限定 lineage/服务，失败非零退出，清理本次临时私钥，不打印秘密。参考 [Certbot 官方续期说明](https://eff-certbot.readthedocs.io/en/stable/using.html#renewing-certificates)。

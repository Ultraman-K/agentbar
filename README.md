# AgentBar

当前版本：`1.0.4`

macOS 菜单栏工具：查看 AI Agent 的额度、重置时间、余额与告警状态。

> 适合已在本机登录 Codex CLI、希望不打开 Codex 也能随时查看额度的用户。

## 功能

- 状态栏显示 Codex `5h` / `7d` 剩余额度，支持圆环、额度数字分别开关。
- 状态栏可单独显示 DeepSeek CNY 余额；Codex 与 DeepSeek 之间使用竖线分隔，适合刘海屏场景。
- 展开菜单展示 Codex 5 小时额度、每周额度、完整重置次数、最近到期时间和数据新鲜度。
- 展开菜单展示 DeepSeek 余额和数据新鲜度；未配置 API Key 时显示明确的空状态。
- 设置窗口支持按供应商自定义状态栏元素、DeepSeek API Key、直接连接或 Clash 代理。
- DeepSeek 余额每 1 分钟自动刷新，也支持从展开菜单手动刷新；Codex 与 DeepSeek 独立显示刷新状态。
- 剩余 `51%–100%` 显示白色；`20%–50%` 显示黄色 `!`；`0%–19%` 显示红色 `⚠`。

本期 MVP 只接入 Codex 和 DeepSeek，不包含成本估算、缓存命中率、历史统计或其他供应商。

## 数据来源与隐私

- **Codex 实时额度**：通过本机已登录的 Codex CLI 实时读取账号额度。
- **Codex 重置次数**：通过 Codex app-server 返回的重置数据读取可用次数和最近到期时间。
- **DeepSeek 余额**：使用 DeepSeek 官方余额接口读取 CNY 余额。
- **本地缓存**：实时读取暂时不可用时，保留最后一次可信额度并标明非实时或已过期；不会使用会话日志猜测当前额度。
- DeepSeek API Key 只保存到 macOS 钥匙串；不会写入 UserDefaults、余额缓存或日志。
- 本地缓存只保存额度、重置时间、余额与更新时间；不读取或保存认证 token、prompt、回复或会话正文。
- 运行日志写入当前代码目录的 `./logs/`，只记录脱敏后的生命周期、刷新、子进程和错误信息；单文件超过 1 MiB 自动轮转。

## 系统要求

- macOS 13 或更高版本。
- Swift 6 工具链（可通过 Xcode Command Line Tools 获得）。
- 已安装并可在终端运行的 Codex CLI，且已完成登录。

可先确认环境：

```zsh
swift --version
command -v codex
```

## 安装

当前推荐从源码安装。将 `<仓库地址>` 换成你的 GitHub/GitLab 仓库地址：

```zsh
git clone <仓库地址> agentbar
cd agentbar
./scripts/install.sh
```

安装后，菜单栏会出现 AgentBar。默认不启用登录时自动启动，可在设置中开启。

安装位置：

```text
~/Library/Application Support/CodexQuotaMenu/bin/agentbar
```

配置、缓存和钥匙串标识继续沿用旧版 `CodexQuotaMenu` 命名，确保升级后数据不丢失。

## 使用与升级

- 点击菜单栏项目查看 Codex 与 DeepSeek 的完整数据。
- 点击“立即刷新”手动更新。
- 若 Codex 显示 `--`，先确认 `codex` 已登录。
- 若 DeepSeek 显示未配置，打开“设置 → 供应商配置”填写 API Key。

升级到仓库最新代码时，先停止旧进程，再重新安装，避免旧进程继续运行已加载的二进制：

```zsh
cd agentbar
git pull

BIN="$HOME/Library/Application Support/CodexQuotaMenu/bin/agentbar"
pkill -TERM -f "$BIN" 2>/dev/null || true
./scripts/install.sh
```

## 卸载

```zsh
./scripts/uninstall.sh
```

默认卸载保留本地缓存和代码目录下的日志。需要一并清除：

```zsh
./scripts/uninstall.sh --purge
```

## 分享给其他人

最简单方式：将仓库推送到 GitHub 或 GitLab，并让使用者按“安装”章节执行。

当前项目尚未提供签名、公证或免编译的二进制发布物。若希望非开发者一键安装，需要后续发布签名并公证的 `.app` 或 release 二进制到 GitHub Releases；在此之前，源码安装是可靠的分发方式。

## 开发验证

```zsh
swift test
swift build -c release --disable-sandbox
```

## 故障排查

- 显示“数据已过期”：实时数据未能在额度重置后更新，工具保留最后一次可信数据，但不将其伪装为实时额度。
- 显示“未找到 Codex CLI”：确认 `command -v codex` 有输出，并重新安装以更新启动环境。
- 登录自启失败：检查 `~/Library/LaunchAgents/com.codex.quota-menu.plist` 与 `launchctl` 错误信息。

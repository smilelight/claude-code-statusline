# Claude Code Statusline

自定义 Claude Code 状态栏脚本，风格灵感来自 Oh My Zsh robbyrussell 主题。

## 效果预览

```
➜  project_name  master ✗ ◔ 28% 󰚩 Opus 4.6 💰3.19(⬆︎0.05) [11日 💰1.25]
```

## 功能

| 模块 | 说明 |
|------|------|
| `➜ project_name` | 当前目录名 |
| ` master ✗` | Git 分支 + dirty 状态（Nerd Font 图标） |
| `◔ 28%` | 上下文使用率，饼图 + 5 档渐变色 |
| `󰚩 Opus 4.6` | 当前模型（Nerd Font 机器人图标） |
| `💰3.19(⬆︎0.05)` | 会话累计费用 + 本次刷新增量 |
| `[11日 💰1.25]` | 今日所有会话总花费 |

## 上下文颜色档位

| 范围 | 颜色 | 饼图 |
|------|------|------|
| 0-20% | 绿色 | ○ |
| 21-40% | 青色 | ◔ |
| 41-60% | 黄色 | ◑ |
| 61-80% | 橙色 | ◕ |
| 81-100% | 红色 | ● |

## 依赖

- **zsh** (macOS 默认)
- **jq** (JSON 解析)
- **bc** (费用计算)
- **Nerd Font** (推荐 MesloLGS Nerd Font)

```bash
brew install jq
brew install --cask font-meslo-lg-nerd-font
```

安装字体后需在终端 app 中设置字体为 `MesloLGS Nerd Font`。

## 安装

1. 复制脚本到 Claude Code 配置目录：

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
```

2. 在 `~/.claude/settings.json` 中配置：

```json
{
  "statusline": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

## 数据存储

- `/tmp/claude_statusline_cost_{session_id}` - 单次刷新增量追踪
- `/tmp/claude_daily_costs/` - 每日费用基准和增量文件（按天自动隔离）

## 输入数据

脚本通过 stdin 接收 Claude Code 传入的 JSON，包含：

```json
{
  "session_id": "...",
  "cwd": "/path/to/project",
  "model": { "display_name": "Opus 4.6" },
  "cost": { "total_cost_usd": 2.37 },
  "context_window": { "used_percentage": 28 }
}
```

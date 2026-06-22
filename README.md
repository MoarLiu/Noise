# Noise

白噪音番茄闹钟。

Noise 是一个本地优先的 macOS 专注 App，把番茄计时、白噪音声景、菜单栏倒计时和轻量专注统计放在一起。

## 当前 MVP

- 番茄计时：专注、短休息、长休息、暂停、继续、停止。
- 循环计划：自定义时长、长休息间隔、自动开始下一轮。
- 声景：专注声音、休息声音、音量控制。
- 声景管理：分组声音选择、声景预设、声音试听。
- 通知：番茄/休息完成后发送 macOS 通知。
- 记录：今日专注、近 7 天统计、高频任务、CSV/Markdown 导出。
- 菜单栏：状态、快速开始、暂停继续、打开主窗口。
- 打包：本地 `.app` 和 DMG 生成脚本。

## 开发

```bash
./script/build_and_run.sh
```

构建：

```bash
swift build
```

运行回归测试：

```bash
./script/run_tests.sh
```

生成 DMG：

```bash
./script/package_dmg.sh
```

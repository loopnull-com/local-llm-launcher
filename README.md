# Local LLM Launcher

[English](#english) | [简体中文](#简体中文)

## English

Local LLM Launcher is a lightweight Windows launcher and system tray controller for local llama.cpp servers. It provides a menu-driven batch launcher for selecting GGUF models and runtime profiles, plus a PowerShell/WinForms tray controller that owns and monitors the server process.

This repository does **not** include llama.cpp binaries, CUDA DLLs, or GGUF models. You must obtain the llama.cpp Windows runtime and model files separately.

Local LLM Launcher is an independent third-party launcher/controller. [llama.cpp](https://github.com/ggml-org/llama.cpp) is a separate project; this repository is not an official llama.cpp project and does not redistribute its binaries.

### Features

- Recursively scans `models\` for GGUF files.
- Excludes `mmproj*` files from the main model list and lists only the first shard of split GGUF models.
- Detects vision `mmproj*.gguf` files beside the selected model, with enable/disable or selection prompts.
- Provides Fast, Thinking, Custom, and Diagnostic modes.
- Supports custom context size, maximum output tokens, and reasoning `on`/`off`/`auto`.
- Preserves the existing llama.cpp policy: `-ngl auto`, `-fit on`, `-fa auto`, and `--parallel 1`.
- Runs `llama-server` hidden in normal modes and controls it from a WinForms notification-area icon.
- Checks for port conflicts and server readiness, then opens the llama.cpp Web UI.
- Captures server stdout/stderr, rotates logs, detects abnormal exits, and safely stops the owned server when exiting.
- Includes a foreground Diagnostic mode with device listing and more detailed backend logging.

### Requirements

- Windows with Windows PowerShell and WinForms support.
- A compatible Windows build of llama.cpp containing `llama-server.exe` and its required dependencies.
- One or more GGUF model files.
- Hardware and drivers suitable for the llama.cpp build and model you choose.

Compatibility depends on the particular llama.cpp build, model, drivers, and hardware. No universal model or GPU compatibility is claimed.

### Installation / setup

1. Download or clone this repository.
2. Prepare the llama.cpp runtime in `runtime\`.
3. Place GGUF models in `models\` or its subdirectories.
4. Optional: copy `config.example.cmd` to `config.cmd` and adjust the machine-specific settings.
5. Run `launcher.bat`.

### Prepare the llama.cpp runtime

Obtain a Windows build from the independent llama.cpp project. Put the server executable and every dependency required by that release in `runtime\`, including:

```text
runtime\
├─ llama-server.exe
├─ llama.dll
├─ ggml.dll
├─ ggml-base.dll
├─ ggml-cuda.dll        (when required by the selected build)
└─ other required DLLs
```

The required file is `runtime\llama-server.exe`. Do not put llama.cpp files in the repository root. The repository intentionally ignores user-provided files in `runtime\`.

### Add GGUF models

Place models directly under `models\` or organize them in subdirectories:

```text
models\
├─ text-model.gguf
└─ vision-model\
   ├─ model-00001-of-00002.gguf
   ├─ model-00002-of-00002.gguf
   └─ mmproj-model-f16.gguf
```

The launcher scans recursively. Files beginning with `mmproj` are not offered as main models. For split files, only the `-00001-of-` shard appears in the model menu.

### Run the launcher

Double-click `launcher.bat` or start it from Command Prompt. Select a model, choose an available vision projector when detected, and then choose a mode. Normal modes hand off to the hidden tray controller; Diagnostic mode keeps the server in the foreground.

### Modes

| Mode | Reasoning | Context | Max output | Behavior |
|---|---:|---:|---:|---|
| Fast | Off | 8192 | 4096 | Normal tray-controlled startup |
| Thinking | On | 16384 | 8192 | Normal tray-controlled startup |
| Custom | Off / On / Auto | User-selected | User-selected | Normal tray-controlled startup |
| Diagnostic | Off | 8192 | 4096 | Lists llama.cpp devices and uses detailed log verbosity in the foreground |

### Vision / mmproj support

Keep each `mmproj*.gguf` beside its corresponding main model. If one projector is found, the launcher asks whether to enable it. If several are found, the launcher lets you disable vision or select one projector. The launcher does not attempt to determine whether an arbitrary projector matches an arbitrary model.

### Tray controller

In Fast, Thinking, and Custom modes, the tray icon shows startup/running/stopped status and provides:

- **Open Chat** — opens the llama.cpp Web UI after readiness is confirmed.
- **Open Log** — opens the current server log.
- **Exit** — stops the server process owned by the controller and exits the controller.

The controller also monitors readiness, startup timeout, and unexpected server exit.

### Logs

Normal tray-controlled runs create `logs\llama-server-YYYYMMDD-HHMMSS.log` and capture both stdout and stderr. Rotation retains the current log and the two most recent older matching logs. Diagnostic mode displays its detailed server output in the foreground console. The `logs\` directory and `*.log` files are ignored by Git.

### Configuration

Defaults are defined in `launcher.bat`. To override the machine-specific values, copy `config.example.cmd` to `config.cmd`:

| Variable | Default | Purpose |
|---|---|---|
| `HOST` | `127.0.0.1` | llama-server bind address and probe address |
| `PORT` | `8080` | llama-server TCP port and probe port |
| `CPU_THREADS` | `16` | Value passed to `-t` and `-tb` |
| `LOAD_MODE` | `none` | Value passed to `--load-mode` |

`config.cmd` is local and ignored by Git. The launcher passes these values explicitly to the tray controller, so normal and Diagnostic modes use the same settings.

### Directory structure

```text
local-llm-launcher\
├─ assets\
│  ├─ llama-tray.ico
│  └─ llama-ui-favicon.svg
├─ runtime\
│  └─ README.md
├─ models\
│  └─ README.md
├─ launcher.bat
├─ tray-controller.ps1
├─ config.example.cmd
├─ .gitignore
└─ README.md
```

`logs\` is created when needed and is not committed.

### Troubleshooting

- **`llama-server.exe was not found`**: ensure `runtime\llama-server.exe` exists and its required DLLs are in `runtime\`.
- **No model found**: add a main `.gguf` file under `models\`; a file beginning with `mmproj` is not a main model.
- **Port conflict**: stop the process using the configured host/port, or change `PORT` in `config.cmd`.
- **Startup failure or timeout**: open the current log from the tray, or inspect the Diagnostic mode output. Check that the chosen model, runtime build, drivers, and available memory are suitable.
- **Vision does not work**: verify that the correct `mmproj*.gguf` is beside the selected main GGUF and enable it in the prompt.

---

## 简体中文

Local LLM Launcher 是一个轻量的 Windows 启动器和系统托盘控制器，用于启动和管理本地 llama.cpp 服务器。它使用 BAT 提供模型与运行模式菜单，并由 PowerShell/WinForms 托盘控制器持有和监控服务器进程。

本仓库**不包含** llama.cpp 二进制文件、CUDA DLL 或 GGUF 模型。用户需要自行获取 llama.cpp Windows runtime 和模型文件。

Local LLM Launcher 是独立的第三方 launcher/controller；[llama.cpp](https://github.com/ggml-org/llama.cpp) 是另一个独立项目。本项目不是 llama.cpp 官方项目，也不在仓库中再分发其二进制文件。

### 主要功能

- 递归扫描 `models\` 中的 GGUF，忽略作为主模型的 `mmproj*`，split GGUF 只显示第一 shard。
- 自动查找主模型同目录的 `mmproj*.gguf`，支持启用、禁用或多文件选择。
- 提供 Fast、Thinking、Custom、Diagnostic 四种模式。
- Custom 支持 reasoning `on`/`off`/`auto`、自定义 context 和最大输出 tokens。
- Normal 模式隐藏启动服务器，由 WinForms 托盘负责 readiness、日志、异常退出监控和安全退出。
- Diagnostic 模式显示 llama.cpp device 信息并使用更详细的日志级别。

### 环境要求与准备

需要 Windows、Windows PowerShell/WinForms、用户自行获取的 llama.cpp Windows build，以及至少一个 GGUF 模型。实际兼容性取决于所用 llama.cpp build、模型、驱动与硬件，本项目不承诺支持所有模型或所有显卡。

1. 将 `llama-server.exe`、其 DLL 和发行包要求的其他依赖放入 `runtime\`。
2. 将 GGUF 放入 `models\` 或其子目录；视觉模型的 `mmproj*.gguf` 放在对应主模型同目录。
3. 如需覆盖机器相关设置，将 `config.example.cmd` 复制为 `config.cmd` 并修改。
4. 运行 `launcher.bat`，依次选择模型、视觉 projector（如有）和模式。

### 模式区别

| 模式 | Reasoning | Context | 最大输出 | 运行方式 |
|---|---:|---:|---:|---|
| Fast | Off | 8192 | 4096 | 托盘控制 |
| Thinking | On | 16384 | 8192 | 托盘控制 |
| Custom | Off / On / Auto | 用户输入 | 用户输入 | 托盘控制 |
| Diagnostic | Off | 8192 | 4096 | 前台运行，device 检查与详细日志 |

服务器参数策略仍包括 `-ngl auto`、`-fit on`、`-fa auto` 和 `--parallel 1`。

### 托盘与日志

托盘提供打开聊天页面、打开当前日志和退出模型。控制器会检测服务 readiness、启动超时和异常退出；退出时只清理其持有的 server/controller。Normal 模式的 stdout/stderr 写入 `logs\llama-server-*.log`，保留当前日志和最近两个旧日志。`logs\` 与日志文件不会被 Git 跟踪。

### 配置

`launcher.bat` 提供 `HOST=127.0.0.1`、`PORT=8080`、`CPU_THREADS=16`、`LOAD_MODE=none` 默认值；根目录存在 `config.cmd` 时会调用它覆盖默认值。Launcher 会把这些值明确传给 Tray Controller，Diagnostic watcher 也使用相同 host/port。`config.cmd` 不进入 Git。

### 常见问题

- 找不到 server：确认 `runtime\llama-server.exe` 和依赖 DLL 已放好。
- 找不到模型：确认 `models\` 下存在不以 `mmproj` 开头的主 GGUF。
- 端口冲突：关闭占用配置端口的进程，或在 `config.cmd` 中更换 `PORT`。
- 启动失败或超时：查看托盘当前日志或 Diagnostic 前台输出，并检查模型、runtime、驱动和可用内存。
- 视觉功能不可用：确认选择了正确的 `mmproj`，且它与主模型位于同一目录。

# llama.cpp runtime

Place a Windows build of llama.cpp in this directory. The launcher expects this file to exist:

```text
runtime\llama-server.exe
```

Keep `llama-server.exe` and all DLLs and other files required by that llama.cpp release together in `runtime\`.

Obtain the Windows build yourself from the independent [llama.cpp project](https://github.com/ggml-org/llama.cpp). Do not place llama.cpp runtime files in the repository root. Runtime binaries are not tracked by Git.

## 简体中文

此目录用于放置用户自行获取的 llama.cpp Windows runtime。启动器要求以下文件存在：

```text
runtime\llama-server.exe
```

请将 `llama-server.exe` 依赖的 DLL 和该发行包要求的其他文件一起放在 `runtime\` 中，不要放在仓库根目录。Git 不会跟踪这些 runtime 文件。

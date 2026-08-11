# Models

Place GGUF model files in this directory. Subdirectories are supported. For a vision model, keep its `mmproj*.gguf` file in the same directory as the corresponding main GGUF file.

Example:

```text
models\
└─ example-model\
   ├─ model.gguf
   └─ mmproj-model-f16.gguf
```

Model files are intentionally not tracked by Git.

## 简体中文

请将 GGUF 模型放在此目录中；支持使用子目录。视觉模型的 `mmproj*.gguf` 建议与对应的主 GGUF 放在同一目录。

模型文件不会被 Git 跟踪。

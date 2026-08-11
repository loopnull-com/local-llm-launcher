@echo off
REM Copy this file to config.cmd, then edit the values for your machine.
REM config.cmd is intentionally ignored by Git.

REM Address and TCP port used by llama-server and readiness checks.
set "HOST=127.0.0.1"
set "PORT=8080"

REM CPU threads used for both -t and -tb.
set "CPU_THREADS=16"

REM llama.cpp model loading mode. "none" is equivalent to the legacy --no-mmap behavior.
set "LOAD_MODE=none"

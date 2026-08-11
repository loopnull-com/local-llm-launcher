@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

title llama.cpp Local Model Launcher
cd /d "%~dp0"

REM ============================================================
REM Basic configuration
REM ============================================================

set "ROOT_DIR=%~dp0"

set "SERVER=%ROOT_DIR%runtime\llama-server.exe"
set "MODEL_DIR=%ROOT_DIR%models"
set "CONTROLLER=%ROOT_DIR%tray-controller.ps1"

set "HOST=127.0.0.1"
set "PORT=8080"

REM CPU thread limit
set "CPU_THREADS=16"

REM Model loading mode
REM none = equivalent to legacy --no-mmap
set "LOAD_MODE=none"

REM Optional machine-specific overrides (not tracked by Git)
if exist "%ROOT_DIR%config.cmd" call "%ROOT_DIR%config.cmd"


REM ============================================================
REM Environment check
REM ============================================================

if not exist "%SERVER%" (
    cls
    echo ==========================================
    echo ERROR: llama-server.exe was not found.
    echo ==========================================
    echo.
    echo Expected path:
    echo %SERVER%
    echo.
    pause
    exit /b 1
)

if not exist "%MODEL_DIR%" (
    cls
    echo ==========================================
    echo ERROR: models directory was not found.
    echo ==========================================
    echo.
    echo Expected path:
    echo %MODEL_DIR%
    echo.
    pause
    exit /b 1
)

if not exist "%CONTROLLER%" (
    cls
    echo ==========================================
    echo ERROR: tray-controller.ps1 was not found.
    echo ==========================================
    echo.
    echo Expected path:
    echo %CONTROLLER%
    echo.
    pause
    exit /b 1
)


REM ============================================================
REM Main model menu
REM ============================================================

:MODEL_MENU

cls

echo ==========================================
echo        llama.cpp Local Model Launcher
echo ==========================================
echo.


echo Scanning models...
echo.

set "MODEL_COUNT=0"


REM ============================================================
REM Scan GGUF models
REM ============================================================

for /r "%MODEL_DIR%" %%F in (*.gguf) do (

    set "NAME=%%~nxF"
    set "SKIP=0"

    REM Ignore mmproj files
    echo(!NAME! | findstr /i /b /l /c:"mmproj" >nul
    if not errorlevel 1 (
        set "SKIP=1"
    )

    REM For split GGUF files, only show the first shard
    if "!SKIP!"=="0" (

        echo(!NAME! | findstr /i /l /c:"-of-" >nul

        if not errorlevel 1 (

            echo(!NAME! | findstr /i /l /c:"-00001-of-" >nul

            if errorlevel 1 (
                set "SKIP=1"
            )
        )
    )

    REM Add model to list
    if "!SKIP!"=="0" (

        set /a MODEL_COUNT+=1

        set "MODEL_PATH[!MODEL_COUNT!]=%%~fF"

        set "DISPLAY=%%~fF"
        set "DISPLAY=!DISPLAY:%MODEL_DIR%\=!"

        set "MODEL_NAME[!MODEL_COUNT!]=!DISPLAY!"
    )
)


REM ============================================================
REM No model found
REM ============================================================

if !MODEL_COUNT! EQU 0 (

    cls

    echo ==========================================
    echo No GGUF model found.
    echo ==========================================
    echo.
    echo Put your model files inside:
    echo %MODEL_DIR%
    echo.
    echo Files beginning with mmproj are ignored.
    echo.

    pause
    goto MODEL_MENU
)


REM ============================================================
REM Show model list
REM ============================================================

cls

echo ==========================================
echo              Select Model
echo ==========================================
echo.

for /l %%I in (1,1,!MODEL_COUNT!) do (
    echo [%%I] !MODEL_NAME[%%I]!
)

echo.
echo [R] Rescan
echo [Q] Quit
echo.
echo ==========================================
echo.

set "CHOICE="
set /p "CHOICE=Select: "

if /i "!CHOICE!"=="Q" (
    exit /b 0
)

if /i "!CHOICE!"=="R" (
    goto MODEL_MENU
)

set "MODEL="
set "MODEL_DISPLAY="

for /l %%I in (1,1,!MODEL_COUNT!) do (

    if "!CHOICE!"=="%%I" (

        set "MODEL=!MODEL_PATH[%%I]!"
        set "MODEL_DISPLAY=!MODEL_NAME[%%I]!"
    )
)

if not defined MODEL (
    goto MODEL_MENU
)


REM ============================================================
REM Get selected model directory
REM ============================================================

for %%D in ("!MODEL!") do (
    set "MODEL_FOLDER=%%~dpD"
)


REM ============================================================
REM Scan mmproj files in selected model directory
REM ============================================================

set "MMPROJ_COUNT=0"
set "MMPROJ="

for %%F in ("!MODEL_FOLDER!mmproj*.gguf") do (

    if exist "%%~fF" (

        set /a MMPROJ_COUNT+=1

        set "MMPROJ_PATH[!MMPROJ_COUNT!]=%%~fF"
        set "MMPROJ_NAME[!MMPROJ_COUNT!]=%%~nxF"
    )
)


REM ============================================================
REM No mmproj found
REM ============================================================

if !MMPROJ_COUNT! EQU 0 (
    goto MODE_MENU
)


REM ============================================================
REM One mmproj found
REM ============================================================

if !MMPROJ_COUNT! EQU 1 (

    cls

    echo ==========================================
    echo             Vision Model
    echo ==========================================
    echo.
    echo Detected:
    echo !MMPROJ_NAME[1]!
    echo.
    echo [1] Enable vision
    echo [2] Disable vision
    echo [B] Back
    echo.
    echo ==========================================
    echo.

    set "MM_CHOICE="
    set /p "MM_CHOICE=Select: "

    if "!MM_CHOICE!"=="1" (
        set "MMPROJ=!MMPROJ_PATH[1]!"
        goto MODE_MENU
    )

    if "!MM_CHOICE!"=="2" (
        set "MMPROJ="
        goto MODE_MENU
    )

    if /i "!MM_CHOICE!"=="B" (
        goto MODEL_MENU
    )

    goto MODEL_MENU
)


REM ============================================================
REM Multiple mmproj files
REM ============================================================

:MMPROJ_MENU

cls

echo ==========================================
echo            Select Vision Model
echo ==========================================
echo.
echo [0] Disable vision
echo.

for /l %%I in (1,1,!MMPROJ_COUNT!) do (
    echo [%%I] !MMPROJ_NAME[%%I]!
)

echo.
echo [B] Back
echo.
echo ==========================================
echo.

set "MM_CHOICE="
set /p "MM_CHOICE=Select: "

if "!MM_CHOICE!"=="0" (
    set "MMPROJ="
    goto MODE_MENU
)

if /i "!MM_CHOICE!"=="B" (
    goto MODEL_MENU
)

set "MMPROJ="

for /l %%I in (1,1,!MMPROJ_COUNT!) do (

    if "!MM_CHOICE!"=="%%I" (
        set "MMPROJ=!MMPROJ_PATH[%%I]!"
    )
)

if not defined MMPROJ (
    goto MMPROJ_MENU
)

goto MODE_MENU


REM ============================================================
REM Runtime mode menu
REM ============================================================

:MODE_MENU

cls

echo ==========================================
echo              Select Mode
echo ==========================================
echo.
echo [1] Fast
echo     Reasoning : OFF
echo     Context   : 8192
echo     Max Output: 4096
echo.
echo [2] Thinking
echo     Reasoning : ON
echo     Context   : 16384
echo     Max Output: 8192
echo.
echo [3] Custom
echo.
echo [4] Diagnostic
echo     Fast settings + detailed backend logs
echo     Shows CUDA / GPU offload / memory info
echo.
echo [B] Back to model list
echo [Q] Quit
echo.
echo ==========================================
echo.

set "MODE_CHOICE="
set /p "MODE_CHOICE=Select: "


REM ============================================================
REM Fast mode
REM ============================================================

if "!MODE_CHOICE!"=="1" (

    set "MODE_NAME=Fast"
    set "REASONING=off"
    set "CTX_SIZE=8192"
    set "PREDICT=4096"
    set "LOG_VERBOSITY=2"
    set "LOG_LABEL=quiet"
    set "DIAGNOSTIC=0"

    goto START_SERVER
)


REM ============================================================
REM Thinking mode
REM ============================================================

if "!MODE_CHOICE!"=="2" (

    set "MODE_NAME=Thinking"
    set "REASONING=on"
    set "CTX_SIZE=16384"
    set "PREDICT=8192"
    set "LOG_VERBOSITY=2"
    set "LOG_LABEL=quiet"
    set "DIAGNOSTIC=0"

    goto START_SERVER
)


REM ============================================================
REM Custom mode
REM ============================================================

if "!MODE_CHOICE!"=="3" (
    goto CUSTOM_MODE
)


REM ============================================================
REM Diagnostic mode
REM ============================================================

if "!MODE_CHOICE!"=="4" (

    set "MODE_NAME=Diagnostic"
    set "REASONING=off"
    set "CTX_SIZE=8192"
    set "PREDICT=4096"
    set "LOG_VERBOSITY=4"
    set "LOG_LABEL=detailed"
    set "DIAGNOSTIC=1"

    goto START_SERVER
)


if /i "!MODE_CHOICE!"=="B" (
    goto MODEL_MENU
)

if /i "!MODE_CHOICE!"=="Q" (
    exit /b 0
)

goto MODE_MENU


REM ============================================================
REM Custom mode
REM ============================================================

:CUSTOM_MODE

cls

echo ==========================================
echo              Custom Mode
echo ==========================================
echo.
echo Reasoning:
echo.
echo [1] OFF
echo [2] ON
echo [3] AUTO
echo [B] Back
echo.

set "CUSTOM_REASONING="
set /p "CUSTOM_REASONING=Select: "

if "!CUSTOM_REASONING!"=="1" (
    set "REASONING=off"
) else if "!CUSTOM_REASONING!"=="2" (
    set "REASONING=on"
) else if "!CUSTOM_REASONING!"=="3" (
    set "REASONING=auto"
) else if /i "!CUSTOM_REASONING!"=="B" (
    goto MODE_MENU
) else (
    goto CUSTOM_MODE
)


REM ============================================================
REM Custom context
REM ============================================================

:CUSTOM_CONTEXT

cls

echo ==========================================
echo              Custom Mode
echo ==========================================
echo.
echo Enter context size.
echo.
echo Examples:
echo 8192
echo 16384
echo 32768
echo 65536
echo 131072
echo.
echo [B] Back
echo.

set "CTX_SIZE="
set /p "CTX_SIZE=Context: "

if /i "!CTX_SIZE!"=="B" (
    goto CUSTOM_MODE
)

if not defined CTX_SIZE (
    goto CUSTOM_CONTEXT
)

echo(!CTX_SIZE! | findstr /r /x "[0-9][0-9]*" >nul

if errorlevel 1 (
    goto CUSTOM_CONTEXT
)


REM ============================================================
REM Custom max output
REM ============================================================

:CUSTOM_OUTPUT

cls

echo ==========================================
echo              Custom Mode
echo ==========================================
echo.
echo Enter maximum output tokens.
echo.
echo Examples:
echo 2048
echo 4096
echo 8192
echo 16384
echo.
echo [B] Back
echo.

set "PREDICT="
set /p "PREDICT=Max Output: "

if /i "!PREDICT!"=="B" (
    goto CUSTOM_CONTEXT
)

if not defined PREDICT (
    goto CUSTOM_OUTPUT
)

echo(!PREDICT! | findstr /r /x "[0-9][0-9]*" >nul

if errorlevel 1 (
    goto CUSTOM_OUTPUT
)

set "MODE_NAME=Custom"
set "LOG_VERBOSITY=2"
set "LOG_LABEL=quiet"
set "DIAGNOSTIC=0"

goto START_SERVER


REM ============================================================
REM Start server
REM ============================================================

:START_SERVER

cls

echo ==========================================
echo              Start Model
echo ==========================================
echo.
echo Model:
echo !MODEL_DISPLAY!
echo.
echo Mode       : !MODE_NAME!
echo Reasoning  : !REASONING!
echo Context    : !CTX_SIZE!
echo Max Output : !PREDICT!
echo GPU Layers : auto
echo Auto Fit   : ON
echo Flash Attn : auto
echo Parallel   : 1
echo CPU Threads: !CPU_THREADS!
echo Load Mode  : !LOAD_MODE!
echo Logging    : !LOG_LABEL!
echo.

if defined MMPROJ (
    echo Vision     : ON
) else (
    echo Vision     : OFF
)

echo.
echo Server:
echo http://%HOST%:%PORT%
echo.
echo ==========================================
echo.


REM ============================================================
REM Port conflict check
REM ============================================================

powershell.exe -NoProfile -NonInteractive -Command "$client = New-Object System.Net.Sockets.TcpClient; try { $task = $client.ConnectAsync($env:HOST, [int]$env:PORT); if ($task.Wait(400) -and $client.Connected) { exit 1 }; exit 0 } catch { exit 0 } finally { $client.Dispose() }"

if errorlevel 1 (
    echo Port %PORT% on %HOST% is already in use. Please close the existing instance first.
    echo.
    pause
    goto MODE_MENU
)


REM ============================================================
REM Diagnostic device check
REM ============================================================

if "!DIAGNOSTIC!"=="1" (

    echo Detected llama.cpp devices:
    echo.

    "%SERVER%" --list-devices

    echo.
    echo ==========================================
    echo.
)


echo Loading model...
echo.


REM ============================================================
REM Normal modes: hand off to the hidden tray controller
REM ============================================================

if "!DIAGNOSTIC!"=="0" (

    if defined MMPROJ (
        start "" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%CONTROLLER%" -ServerPath "%SERVER%" -HostAddress "%HOST%" -ServerPort "%PORT%" -CpuThreads "%CPU_THREADS%" -LoadMode "%LOAD_MODE%" -ModelPath "!MODEL!" -MmprojPath "!MMPROJ!" -Reasoning "!REASONING!" -ContextSize "!CTX_SIZE!" -Predict "!PREDICT!" -LogVerbosity "!LOG_VERBOSITY!"
    ) else (
        start "" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%CONTROLLER%" -ServerPath "%SERVER%" -HostAddress "%HOST%" -ServerPort "%PORT%" -CpuThreads "%CPU_THREADS%" -LoadMode "%LOAD_MODE%" -ModelPath "!MODEL!" -Reasoning "!REASONING!" -ContextSize "!CTX_SIZE!" -Predict "!PREDICT!" -LogVerbosity "!LOG_VERBOSITY!"
    )

    if errorlevel 1 (
        echo Failed to start tray controller.
        echo.
        pause
        goto MODE_MENU
    )

    exit /b 0
)


REM ============================================================
REM Diagnostic mode: hidden Ready watcher + foreground server
REM ============================================================

start "" powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%CONTROLLER%" -ReadyWatcher -HostAddress "%HOST%" -ServerPort "%PORT%" -ReadyTimeoutSeconds 120


REM ============================================================
REM Run llama-server
REM ============================================================

if defined MMPROJ (

    "%SERVER%" ^
        -m "!MODEL!" ^
        --mmproj "!MMPROJ!" ^
        -ngl auto ^
        -fit on ^
        --load-mode !LOAD_MODE! ^
        -t !CPU_THREADS! ^
        -tb !CPU_THREADS! ^
        -c !CTX_SIZE! ^
        -n !PREDICT! ^
        -fa auto ^
        --parallel 1 ^
        --reasoning !REASONING! ^
        --log-verbosity !LOG_VERBOSITY! ^
        --log-colors off ^
        --host %HOST% ^
        --port %PORT%

) else (

    "%SERVER%" ^
        -m "!MODEL!" ^
        -ngl auto ^
        -fit on ^
        --load-mode !LOAD_MODE! ^
        -t !CPU_THREADS! ^
        -tb !CPU_THREADS! ^
        -c !CTX_SIZE! ^
        -n !PREDICT! ^
        -fa auto ^
        --parallel 1 ^
        --reasoning !REASONING! ^
        --log-verbosity !LOG_VERBOSITY! ^
        --log-colors off ^
        --host %HOST% ^
        --port %PORT%
)

set "SERVER_EXIT=!ERRORLEVEL!"


REM ============================================================
REM Server stopped
REM ============================================================

:SERVER_STOPPED

cls

echo ==========================================
echo          llama-server Stopped
echo ==========================================
echo.
echo Exit code: !SERVER_EXIT!
echo.
echo [1] Change mode
echo [2] Change model
echo [Q] Quit
echo.
echo ==========================================
echo.

set "AFTER_CHOICE="
set /p "AFTER_CHOICE=Select: "

if "!AFTER_CHOICE!"=="1" (
    goto MODE_MENU
)

if "!AFTER_CHOICE!"=="2" (
    goto MODEL_MENU
)

if /i "!AFTER_CHOICE!"=="Q" (
    exit /b 0
)

goto SERVER_STOPPED

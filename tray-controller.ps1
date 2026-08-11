[CmdletBinding(DefaultParameterSetName = 'Controller')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Controller')]
    [ValidateNotNullOrEmpty()]
    [string]$ServerPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$HostAddress,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int]$ServerPort,

    [Parameter(Mandatory = $true, ParameterSetName = 'Controller')]
    [ValidateRange(1, 2147483647)]
    [int]$CpuThreads,

    [Parameter(Mandatory = $true, ParameterSetName = 'Controller')]
    [ValidateNotNullOrEmpty()]
    [string]$LoadMode,

    [Parameter(Mandatory = $true, ParameterSetName = 'Controller')]
    [string]$ModelPath,

    [Parameter(ParameterSetName = 'Controller')]
    [string]$MmprojPath = '',

    [Parameter(Mandatory = $true, ParameterSetName = 'Controller')]
    [ValidateSet('on', 'off', 'auto')]
    [string]$Reasoning,

    [Parameter(Mandatory = $true, ParameterSetName = 'Controller')]
    [ValidateRange(1, 2147483647)]
    [int]$ContextSize,

    [Parameter(Mandatory = $true, ParameterSetName = 'Controller')]
    [ValidateRange(1, 2147483647)]
    [int]$Predict,

    [Parameter(ParameterSetName = 'Controller')]
    [ValidateRange(0, 9)]
    [int]$LogVerbosity = 2,

    [Parameter(Mandatory = $true, ParameterSetName = 'Watcher')]
    [switch]$ReadyWatcher,

    [Parameter(ParameterSetName = 'Watcher')]
    [ValidateRange(1, 600)]
    [int]$ReadyTimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$ChatUrl = 'http://{0}:{1}' -f $HostAddress, $ServerPort
$HealthUrl = $ChatUrl + '/health'

function Quote-WindowsArgument {
    param([AllowEmptyString()][string]$Value)

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    $result = New-Object System.Text.StringBuilder
    [void]$result.Append('"')
    $backslashes = 0

    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') {
            $backslashes++
            continue
        }

        if ($character -eq '"') {
            [void]$result.Append(('\' * (($backslashes * 2) + 1)))
            [void]$result.Append('"')
            $backslashes = 0
            continue
        }

        if ($backslashes -gt 0) {
            [void]$result.Append(('\' * $backslashes))
            $backslashes = 0
        }
        [void]$result.Append($character)
    }

    if ($backslashes -gt 0) {
        [void]$result.Append(('\' * ($backslashes * 2)))
    }
    [void]$result.Append('"')
    return $result.ToString()
}

function Test-TcpPort {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync($HostAddress, $ServerPort)
        return ($task.Wait(400) -and $client.Connected)
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

function Invoke-HttpProbe {
    param([string]$Url)

    try {
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.Method = 'GET'
        $request.Timeout = 1000
        $request.ReadWriteTimeout = 1000
        $request.Proxy = $null
        $response = [System.Net.HttpWebResponse]$request.GetResponse()
        try {
            return [int]$response.StatusCode
        }
        finally {
            $response.Dispose()
        }
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $response = [System.Net.HttpWebResponse]$_.Exception.Response
            try {
                return [int]$response.StatusCode
            }
            finally {
                $response.Dispose()
            }
        }
        return 0
    }
    catch {
        return 0
    }
}

function Test-ServerReady {
    $healthStatus = Invoke-HttpProbe -Url $HealthUrl
    if ($healthStatus -ge 200 -and $healthStatus -lt 300) {
        return $true
    }

    if ($healthStatus -eq 404 -or $healthStatus -eq 405) {
        $rootStatus = Invoke-HttpProbe -Url $ChatUrl
        return ($rootStatus -ge 200 -and $rootStatus -lt 500)
    }

    return $false
}

function Open-ChatPage {
    Start-Process -FilePath $ChatUrl | Out-Null
}

if ($ReadyWatcher) {
    $deadline = [DateTime]::UtcNow.AddSeconds($ReadyTimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-ServerReady) {
            Open-ChatPage
            exit 0
        }
        Start-Sleep -Milliseconds 500
    }
    exit 1
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class LocalLlmDpiAwareness
{
    private const int E_ACCESSDENIED = unchecked((int)0x80070005);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetProcessDpiAwarenessContext(IntPtr dpiContext);

    [DllImport("shcore.dll")]
    private static extern int SetProcessDpiAwareness(int awareness);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetProcessDPIAware();

    public static string Configure()
    {
        try
        {
            // DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
            if (SetProcessDpiAwarenessContext(new IntPtr(-4)))
            {
                return "DPI awareness: PerMonitorV2.";
            }

            if (Marshal.GetLastWin32Error() == 5)
            {
                return "DPI awareness: already configured by the process host.";
            }
        }
        catch (EntryPointNotFoundException) { }
        catch (DllNotFoundException) { }

        try
        {
            // PROCESS_PER_MONITOR_DPI_AWARE
            int result = SetProcessDpiAwareness(2);
            if (result == 0)
            {
                return "DPI awareness: PerMonitor fallback.";
            }
            if (result == E_ACCESSDENIED)
            {
                return "DPI awareness: already configured by the process host.";
            }
        }
        catch (EntryPointNotFoundException) { }
        catch (DllNotFoundException) { }

        try
        {
            if (SetProcessDPIAware())
            {
                return "DPI awareness: System fallback.";
            }
            if (Marshal.GetLastWin32Error() == 5)
            {
                return "DPI awareness: already configured by the process host.";
            }
        }
        catch (EntryPointNotFoundException) { }
        catch (DllNotFoundException) { }

        return "DPI awareness: initialization was unavailable; continuing.";
    }
}
'@

$dpiAwarenessStatus = [LocalLlmDpiAwareness]::Configure()

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

function Show-ErrorMessage {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'Local LLM',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Set-TrayStatus {
    param(
        [string]$Text,
        [bool]$ChatEnabled
    )
    $script:notifyIcon.Text = $Text
    $script:openChatItem.Enabled = $ChatEnabled
}

function Show-TrayNotice {
    param(
        [string]$Title,
        [string]$Text,
        [System.Windows.Forms.ToolTipIcon]$Icon = [System.Windows.Forms.ToolTipIcon]::Info
    )
    $script:notifyIcon.BalloonTipTitle = $Title
    $script:notifyIcon.BalloonTipText = $Text
    $script:notifyIcon.BalloonTipIcon = $Icon
    $script:notifyIcon.ShowBalloonTip(5000)
}

function Write-ControllerLog {
    param([string]$Text)
    if ($script:logWriter) {
        $script:logWriter.WriteLine(('[controller {0:yyyy-MM-dd HH:mm:ss}] {1}' -f (Get-Date), $Text))
        $script:logWriter.Flush()
    }
}

function Drain-ProcessOutput {
    if (-not $script:logWriter) {
        return
    }

    for ($lineCount = 0; $lineCount -lt 200; $lineCount++) {
        $madeProgress = $false

        if (-not $script:stdoutClosed -and $script:stdoutTask.IsCompleted) {
            try {
                $line = $script:stdoutTask.Result
                if ($null -eq $line) {
                    $script:stdoutClosed = $true
                }
                else {
                    $script:logWriter.WriteLine($line)
                    $script:stdoutTask = $script:serverProcess.StandardOutput.ReadLineAsync()
                }
            }
            catch {
                $script:stdoutClosed = $true
                Write-ControllerLog ('stdout read failed: ' + $_.Exception.Message)
            }
            $madeProgress = $true
        }

        if (-not $script:stderrClosed -and $script:stderrTask.IsCompleted) {
            try {
                $line = $script:stderrTask.Result
                if ($null -eq $line) {
                    $script:stderrClosed = $true
                }
                else {
                    $script:logWriter.WriteLine($line)
                    $script:stderrTask = $script:serverProcess.StandardError.ReadLineAsync()
                }
            }
            catch {
                $script:stderrClosed = $true
                Write-ControllerLog ('stderr read failed: ' + $_.Exception.Message)
            }
            $madeProgress = $true
        }

        if (-not $madeProgress) {
            break
        }
    }
    $script:logWriter.Flush()
}

function Stop-OwnedServer {
    if (-not $script:serverProcess -or $script:serverProcess.HasExited) {
        return
    }

    Write-ControllerLog 'Stopping llama-server.'
    $closeRequested = $false
    try {
        $closeRequested = $script:serverProcess.CloseMainWindow()
    }
    catch {
        $closeRequested = $false
    }

    if ($closeRequested) {
        [void]$script:serverProcess.WaitForExit(2000)
    }
    else {
        Start-Sleep -Milliseconds 300
    }

    if (-not $script:serverProcess.HasExited) {
        Write-ControllerLog 'Graceful stop was unavailable; killing llama-server.'
        $script:serverProcess.Kill()
        [void]$script:serverProcess.WaitForExit(5000)
    }

    $drainDeadline = [DateTime]::UtcNow.AddSeconds(2)
    do {
        Drain-ProcessOutput
        if ($script:stdoutClosed -and $script:stderrClosed) {
            break
        }
        Start-Sleep -Milliseconds 10
    } while ([DateTime]::UtcNow -lt $drainDeadline)
    Write-ControllerLog ('llama-server stopped with exit code {0}.' -f $script:serverProcess.ExitCode)
}

$script:serverProcess = $null
$script:notifyIcon = $null
$script:trayIcon = $null
$script:trayMenu = $null
$script:openChatItem = $null
$script:openLogItem = $null
$script:exitItem = $null
$script:applicationContext = $null
$script:controllerTimer = $null
$script:logWriter = $null
$script:logStream = $null
$script:stdoutTask = $null
$script:stderrTask = $null
$script:stdoutClosed = $false
$script:stderrClosed = $false
$script:openChatRequested = $false
$script:openLogRequested = $false
$script:exitRequested = $false
$script:shutdownStarted = $false
$script:startupComplete = $false
$script:serverReady = $false
$script:startupDeadline = $null
$logPath = $null

function Exit-TrayController {
    if ($script:shutdownStarted) {
        return
    }

    $script:shutdownStarted = $true
    if ($script:controllerTimer) {
        $script:controllerTimer.Stop()
    }

    try {
        Stop-OwnedServer
    }
    catch {
        Write-ControllerLog ('Failed to stop llama-server: ' + $_.Exception.Message)
    }

    if ($script:notifyIcon) {
        $script:notifyIcon.Visible = $false
        $script:notifyIcon.Dispose()
        $script:notifyIcon = $null
    }

    if ($script:applicationContext) {
        $script:applicationContext.ExitThread()
    }
}

try {
    if (-not (Test-Path -LiteralPath $ServerPath -PathType Leaf)) {
        Show-ErrorMessage "llama-server.exe 不存在：`r`n$ServerPath"
        exit 1
    }
    if (-not (Test-Path -LiteralPath $ModelPath -PathType Leaf)) {
        Show-ErrorMessage "模型文件不存在：`r`n$ModelPath"
        exit 1
    }
    if ($MmprojPath -and -not (Test-Path -LiteralPath $MmprojPath -PathType Leaf)) {
        Show-ErrorMessage "mmproj 文件不存在：`r`n$MmprojPath"
        exit 1
    }
    if (Test-TcpPort) {
        Show-ErrorMessage "$HostAddress 上的 $ServerPort 端口已被占用，请先关闭已有实例。"
        exit 1
    }

    $logsDirectory = Join-Path $PSScriptRoot 'logs'
    [void][System.IO.Directory]::CreateDirectory($logsDirectory)
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logPath = Join-Path $logsDirectory ("llama-server-$timestamp.log")
    $suffix = 1
    while (Test-Path -LiteralPath $logPath) {
        $logPath = Join-Path $logsDirectory ("llama-server-$timestamp-$suffix.log")
        $suffix++
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $script:logStream = New-Object System.IO.FileStream(
        $logPath,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::ReadWrite
    )
    $script:logWriter = New-Object System.IO.StreamWriter($script:logStream, $utf8NoBom)
    $script:logWriter.AutoFlush = $true
    Write-ControllerLog ('Model: ' + $ModelPath)
    if ($MmprojPath) {
        Write-ControllerLog ('mmproj: ' + $MmprojPath)
    }
    Write-ControllerLog $dpiAwarenessStatus

    try {
        $currentLogFullPath = [System.IO.Path]::GetFullPath($logPath)
        $olderLogs = @(
            Get-ChildItem -LiteralPath $logsDirectory -Filter 'llama-server-*.log' -File |
                Where-Object { [System.IO.Path]::GetFullPath($_.FullName) -ne $currentLogFullPath } |
                Sort-Object -Property @{ Expression = 'LastWriteTime'; Descending = $true }, @{ Expression = 'Name'; Descending = $true }
        )

        foreach ($oldLog in @($olderLogs | Select-Object -Skip 2)) {
            try {
                Remove-Item -LiteralPath $oldLog.FullName -Force -ErrorAction Stop
                Write-ControllerLog ('Removed old log: ' + $oldLog.Name)
            }
            catch {
                Write-ControllerLog ('Failed to remove old log "{0}": {1}' -f $oldLog.Name, $_.Exception.Message)
            }
        }
    }
    catch {
        Write-ControllerLog ('Log cleanup failed: ' + $_.Exception.Message)
    }

    $script:trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $script:trayMenu.Font = [System.Drawing.SystemFonts]::MenuFont
    $titleItem = New-Object System.Windows.Forms.ToolStripMenuItem('Local LLM')
    $titleItem.Enabled = $false
    $script:openChatItem = New-Object System.Windows.Forms.ToolStripMenuItem('打开聊天页面')
    $script:openChatItem.Enabled = $false
    $script:openLogItem = New-Object System.Windows.Forms.ToolStripMenuItem('打开日志')
    $script:exitItem = New-Object System.Windows.Forms.ToolStripMenuItem('退出模型')
    [void]$script:trayMenu.Items.Add($titleItem)
    [void]$script:trayMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$script:trayMenu.Items.Add($script:openChatItem)
    [void]$script:trayMenu.Items.Add($script:openLogItem)
    [void]$script:trayMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$script:trayMenu.Items.Add($script:exitItem)

    $script:openChatItem.add_Click({ $script:openChatRequested = $true })
    $script:openLogItem.add_Click({ $script:openLogRequested = $true })
    $script:exitItem.add_Click({
        param($sender, $eventArgs)
        if (-not $script:exitRequested) {
            $script:exitRequested = $true
            $sender.Enabled = $false
        }
    })

    $script:notifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $iconPath = Join-Path $PSScriptRoot 'assets\llama-tray.ico'
    if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
        throw "托盘图标不存在：$iconPath"
    }
    $script:trayIcon = New-Object System.Drawing.Icon($iconPath)
    $script:notifyIcon.Icon = $script:trayIcon
    $script:notifyIcon.ContextMenuStrip = $script:trayMenu
    $script:notifyIcon.Text = 'Local LLM - 正在启动'
    $script:notifyIcon.Visible = $true

    $arguments = @(
        '-m', $ModelPath
    )
    if ($MmprojPath) {
        $arguments += @('--mmproj', $MmprojPath)
    }
    $arguments += @(
        '-ngl', 'auto',
        '-fit', 'on',
        '--load-mode', $LoadMode,
        '-t', $CpuThreads.ToString([System.Globalization.CultureInfo]::InvariantCulture),
        '-tb', $CpuThreads.ToString([System.Globalization.CultureInfo]::InvariantCulture),
        '-c', $ContextSize.ToString([System.Globalization.CultureInfo]::InvariantCulture),
        '-n', $Predict.ToString([System.Globalization.CultureInfo]::InvariantCulture),
        '-fa', 'auto',
        '--parallel', '1',
        '--reasoning', $Reasoning,
        '--log-verbosity', $LogVerbosity.ToString([System.Globalization.CultureInfo]::InvariantCulture),
        '--log-colors', 'off',
        '--host', $HostAddress,
        '--port', $ServerPort.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $ServerPath
    $startInfo.Arguments = (($arguments | ForEach-Object { Quote-WindowsArgument ([string]$_) }) -join ' ')
    $startInfo.WorkingDirectory = $PSScriptRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    Write-ControllerLog ('Command: ' + $ServerPath + ' ' + $startInfo.Arguments)
    $script:serverProcess = New-Object System.Diagnostics.Process
    $script:serverProcess.StartInfo = $startInfo
    if (-not $script:serverProcess.Start()) {
        throw 'llama-server process could not be started.'
    }
    Write-ControllerLog ('llama-server PID: ' + $script:serverProcess.Id)

    $script:stdoutTask = $script:serverProcess.StandardOutput.ReadLineAsync()
    $script:stderrTask = $script:serverProcess.StandardError.ReadLineAsync()
    $script:startupDeadline = [DateTime]::UtcNow.AddSeconds(120)
    $script:startupComplete = $false
    $script:serverReady = $false

    $script:applicationContext = New-Object System.Windows.Forms.ApplicationContext
    $script:controllerTimer = New-Object System.Windows.Forms.Timer
    $script:controllerTimer.Interval = 100
    $script:controllerTimer.add_Tick({
        try {
            if ($script:exitRequested) {
                Exit-TrayController
                return
            }

            Drain-ProcessOutput

            if ($script:openChatRequested) {
                $script:openChatRequested = $false
                Open-ChatPage
            }
            if ($script:openLogRequested) {
                $script:openLogRequested = $false
                Start-Process -FilePath "$env:SystemRoot\System32\notepad.exe" -ArgumentList (Quote-WindowsArgument $logPath) | Out-Null
            }

            if (-not $script:startupComplete) {
                if ($script:serverProcess.HasExited) {
                    $script:startupComplete = $true
                    Set-TrayStatus -Text 'Local LLM - 已停止' -ChatEnabled $false
                    $script:exitItem.Text = '退出控制器'
                    Write-ControllerLog ('llama-server exited during startup with code {0}.' -f $script:serverProcess.ExitCode)
                    Show-TrayNotice -Title 'Local LLM' -Text '模型启动失败，请查看日志。' -Icon ([System.Windows.Forms.ToolTipIcon]::Error)
                    Show-ErrorMessage "模型启动失败（退出代码 $($script:serverProcess.ExitCode)）。`r`n请查看日志：`r`n$logPath"
                }
                elseif (Test-ServerReady) {
                    $script:startupComplete = $true
                    $script:serverReady = $true
                    Set-TrayStatus -Text 'Local LLM - 运行中' -ChatEnabled $true
                    Write-ControllerLog 'Server is ready.'
                    Show-TrayNotice -Title 'Local LLM' -Text '模型已就绪。'
                    Open-ChatPage
                }
                elseif ([DateTime]::UtcNow -ge $script:startupDeadline) {
                    $script:startupComplete = $true
                    Write-ControllerLog 'Server did not become ready within 120 seconds.'
                    Stop-OwnedServer
                    Set-TrayStatus -Text 'Local LLM - 已停止' -ChatEnabled $false
                    $script:exitItem.Text = '退出控制器'
                    Show-TrayNotice -Title 'Local LLM' -Text '模型启动超时，请查看日志。' -Icon ([System.Windows.Forms.ToolTipIcon]::Error)
                    Show-ErrorMessage "服务器在 2 分钟内未就绪，已停止模型。`r`n请查看日志：`r`n$logPath"
                }
            }
            elseif ($script:serverReady -and $script:serverProcess.HasExited) {
                $script:serverReady = $false
                Drain-ProcessOutput
                Set-TrayStatus -Text 'Local LLM - 已停止' -ChatEnabled $false
                $script:exitItem.Text = '退出控制器'
                Write-ControllerLog ('llama-server exited unexpectedly with code {0}.' -f $script:serverProcess.ExitCode)
                Show-TrayNotice -Title 'Local LLM' -Text '模型进程已意外停止，请查看日志。' -Icon ([System.Windows.Forms.ToolTipIcon]::Error)
            }
        }
        catch {
            Write-ControllerLog ('Fatal controller timer error: ' + $_.Exception.ToString())
            Show-ErrorMessage ("控制器运行失败：`r`n" + $_.Exception.Message + "`r`n`r`n日志：`r`n$logPath")
            Exit-TrayController
        }
    })

    Write-ControllerLog 'Entering WinForms message loop.'
    $script:controllerTimer.Start()
    [System.Windows.Forms.Application]::Run($script:applicationContext)
    Write-ControllerLog 'WinForms message loop exited.'
}
catch {
    if ($script:logWriter) {
        Write-ControllerLog ('Fatal controller error: ' + $_.Exception.ToString())
    }
    Show-ErrorMessage ("启动控制器失败：`r`n" + $_.Exception.Message + $(if ($logPath) { "`r`n`r`n日志：`r`n$logPath" } else { '' }))
}
finally {
    if ($script:controllerTimer) {
        $script:controllerTimer.Stop()
        $script:controllerTimer.Dispose()
    }

    try {
        Stop-OwnedServer
    }
    catch {
        if ($script:logWriter) {
            Write-ControllerLog ('Failed to stop llama-server: ' + $_.Exception.Message)
        }
    }

    if ($script:notifyIcon) {
        $script:notifyIcon.Visible = $false
        $script:notifyIcon.Dispose()
    }
    if ($script:trayIcon) {
        $script:trayIcon.Dispose()
    }
    if ($script:trayMenu) {
        $script:trayMenu.Dispose()
    }
    if ($script:applicationContext) {
        $script:applicationContext.Dispose()
    }
    if ($script:logWriter) {
        $script:logWriter.Flush()
        $script:logWriter.Dispose()
    }
    if ($script:logStream) {
        $script:logStream.Dispose()
    }
    if ($script:serverProcess) {
        $script:serverProcess.Dispose()
    }
}

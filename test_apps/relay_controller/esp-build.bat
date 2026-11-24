@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Standalone Windows build entry point generated for one ESP-IDF example.
set "MSYSTEM="
set "PROJECT_DIR=%~dp0"
set "CONFIG_FILE=%PROJECT_DIR%esp-build-config.json"
set "ESP_BUILD_IDF_PATH="
set "ESP_BUILD_PORT="
set "ESP_BUILD_FLASH_BAUD="
set "ESP_BUILD_MONITOR_BAUD="
set "ESP_BUILD_BAUD_OVERRIDE="
set "ESP_BUILD_DEFAULT_ACTION="
set "ESP_BUILD_CLEAN_PROMPT="
set "ESP_BUILD_FLASH_IMAGES="
set "ESP_BUILD_CCACHE="
set "ESP_BUILD_CONFIG_VALID="
set "ESP_BUILD_IDF_DRY_RUN="
set "ESP_BUILD_LOGGING_ENABLED="
set "ESP_BUILD_LOG_DIR="
set "ESP_BUILD_LOG_KEEP_N="
set "ESP_BUILD_LOG_FILE="
set "ESP_BUILD_MONITOR_CONFIG_VALID="
set "ESP_BUILD_MONITOR_LOG_ENABLED="
set "ESP_BUILD_MONITOR_LOG_MAX_BYTES="
set "ESP_BUILD_MONITOR_SUPPORT_DIR=%PROJECT_DIR%.esp-build-manager\python"
set "ESP_BUILD_MONITOR_LOGGING_ACTIVE="
set "ESP_BUILD_OLD_DONTWRITEBYTECODE="

pushd "%PROJECT_DIR%" >nul
if errorlevel 1 (
    echo ERROR: Could not open project directory:
    echo   "%PROJECT_DIR%"
    exit /b 1
)

if not exist "CMakeLists.txt" (
    echo ERROR: CMakeLists.txt was not found in:
    echo   "%PROJECT_DIR%"
    popd
    exit /b 1
)

if not exist "%CONFIG_FILE%" (
    echo ERROR: Project configuration was not found:
    echo   "%CONFIG_FILE%"
    echo Restore esp-build-config.json or create one from the example configuration.
    popd
    exit /b 1
)

for /f "tokens=1,* delims==" %%A in ('powershell.exe -NoProfile -Command "$ErrorActionPreference = 'Stop'; $c = Get-Content -Raw -LiteralPath $env:CONFIG_FILE | ConvertFrom-Json; if ($c.version -ne 1) { throw 'version must be 1' }; if ($null -ne $c.esp_idf.path -and ($c.esp_idf.path -isnot [string] -or [string]::IsNullOrWhiteSpace($c.esp_idf.path))) { throw 'esp_idf.path must be a non-empty path string or null' }; if ($null -ne $c.serial.port -and ($c.serial.port -isnot [string] -or [string]::IsNullOrWhiteSpace($c.serial.port))) { throw 'serial.port must be a non-empty string or null' }; foreach ($key in @('flash_baudrate','monitor_baudrate')) { $value = $c.serial.$key; if ($null -ne $value -and ($value -isnot [int] -or $value -lt 1 -or $value -gt 2000000)) { throw ('serial.' + $key + ' must be an integer between 1 and 2000000 or null') } }; if (@('build','flash','flash-monitor','ask') -notcontains $c.workflow.default_action) { throw 'workflow.default_action must be build, flash, flash-monitor, or ask' }; if ($c.workflow.clean_build_prompt -isnot [bool] -or $c.build.ccache -isnot [bool] -or $c.storage.flash_images -isnot [bool]) { throw 'workflow.clean_build_prompt, build.ccache, and storage.flash_images must be true or false' }; $logEnabled = if ($c.logging.enabled -is [bool]) { $c.logging.enabled } else { $true }; $logDir = if ($c.logging.directory -is [string]) { $c.logging.directory } else { '.logs' }; $logKeep = if ($c.logging.keep_last_n_logs -is [int]) { $c.logging.keep_last_n_logs } else { 50 }; 'IDF_PATH=' + [string]$c.esp_idf.path; 'PORT=' + [string]$c.serial.port; 'FLASH_BAUD=' + [string]$c.serial.flash_baudrate; 'MONITOR_BAUD=' + [string]$c.serial.monitor_baudrate; 'DEFAULT_ACTION=' + [string]$c.workflow.default_action; 'CLEAN_PROMPT=' + [string]$c.workflow.clean_build_prompt; 'FLASH_IMAGES=' + [string]$c.storage.flash_images; 'CCACHE=' + [string]$c.build.ccache; 'LOGGING_ENABLED=' + [string]$logEnabled; 'LOG_DIR=' + [string]$logDir; 'LOG_KEEP_N=' + [string]$logKeep; 'CONFIG_VALID=1'"') do (
    if /i "%%A"=="IDF_PATH" set "ESP_BUILD_IDF_PATH=%%B"
    if /i "%%A"=="PORT" set "ESP_BUILD_PORT=%%B"
    if /i "%%A"=="FLASH_BAUD" set "ESP_BUILD_FLASH_BAUD=%%B"
    if /i "%%A"=="MONITOR_BAUD" set "ESP_BUILD_MONITOR_BAUD=%%B"
    if /i "%%A"=="DEFAULT_ACTION" set "ESP_BUILD_DEFAULT_ACTION=%%B"
    if /i "%%A"=="CLEAN_PROMPT" set "ESP_BUILD_CLEAN_PROMPT=%%B"
    if /i "%%A"=="FLASH_IMAGES" set "ESP_BUILD_FLASH_IMAGES=%%B"
    if /i "%%A"=="CCACHE" set "ESP_BUILD_CCACHE=%%B"
    if /i "%%A"=="LOGGING_ENABLED" set "ESP_BUILD_LOGGING_ENABLED=%%B"
    if /i "%%A"=="LOG_DIR" set "ESP_BUILD_LOG_DIR=%%B"
    if /i "%%A"=="LOG_KEEP_N" set "ESP_BUILD_LOG_KEEP_N=%%B"
    if /i "%%A"=="CONFIG_VALID" set "ESP_BUILD_CONFIG_VALID=%%B"
)
if not "%ESP_BUILD_CONFIG_VALID%"=="1" (
    echo ERROR: Invalid or unsupported settings in "%CONFIG_FILE%".
    echo Check esp-build-config.json against the example configuration.
    popd
    exit /b 1
)

REM Initialize build logging if enabled
if /i "%ESP_BUILD_LOGGING_ENABLED%"=="True" (
    if not exist "%ESP_BUILD_LOG_DIR%" mkdir "%ESP_BUILD_LOG_DIR%"
    
    REM Create timestamped log filename (YYYY-MM-DD_HH-MM-SS format) using PowerShell
    for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'"`) do set "LOG_TIMESTAMP=%%i"
    set "ESP_BUILD_LOG_FILE=%ESP_BUILD_LOG_DIR%\!LOG_TIMESTAMP!_esp-build.log"
    
    REM Initialize log file with header
    echo ======================================================================= > "!ESP_BUILD_LOG_FILE!"
    echo ESP-IDF Build Log >> "!ESP_BUILD_LOG_FILE!"
    echo ======================================================================= >> "!ESP_BUILD_LOG_FILE!"
    echo Start Time: %date% %time% >> "!ESP_BUILD_LOG_FILE!"
    echo Project Directory: %PROJECT_DIR% >> "!ESP_BUILD_LOG_FILE!"
    echo Config File: %CONFIG_FILE% >> "!ESP_BUILD_LOG_FILE!"
    echo ======================================================================= >> "!ESP_BUILD_LOG_FILE!"
    echo. >> "!ESP_BUILD_LOG_FILE!"
    
    REM Clean old logs (keep only last N logs)
    powershell.exe -NoProfile -Command "$logs = Get-ChildItem '%ESP_BUILD_LOG_DIR%' -Filter '*_esp-build.log' | Sort-Object LastWriteTime -Descending; if ($logs.Count -gt %ESP_BUILD_LOG_KEEP_N%) { $logs | Select-Object -Skip %ESP_BUILD_LOG_KEEP_N% | Remove-Item -Force }" 2>nul
    
    echo Logging enabled: !ESP_BUILD_LOG_FILE!
)

for /f "tokens=1,* delims==" %%A in ('powershell.exe -NoProfile -Command "$ErrorActionPreference = 'Stop'; $c = Get-Content -Raw -LiteralPath $env:CONFIG_FILE | ConvertFrom-Json; $section = $c.PSObject.Properties['monitor']; $enabled = $true; $limit = 1048576; if ($null -ne $section -and $null -ne $section.Value) { $m = $section.Value; if ($m -isnot [System.Management.Automation.PSCustomObject]) { throw 'monitor must be an object' }; $save = $m.PSObject.Properties['save_log']; if ($null -ne $save) { if ($save.Value -isnot [bool]) { throw 'monitor.save_log must be true or false' }; $enabled = $save.Value }; $size = $m.PSObject.Properties['max_log_size_bytes']; if ($null -ne $size) { $value = $size.Value; if (($value -isnot [int] -and $value -isnot [long]) -or $value -lt 1024 -or $value -gt 1073741824) { throw 'monitor.max_log_size_bytes must be an integer between 1024 and 1073741824' }; $limit = $value } }; 'MONITOR_LOG_ENABLED=' + [string]$enabled; 'MONITOR_LOG_MAX_BYTES=' + [string]$limit; 'MONITOR_CONFIG_VALID=1'"') do (
    if /i "%%A"=="MONITOR_LOG_ENABLED" set "ESP_BUILD_MONITOR_LOG_ENABLED=%%B"
    if /i "%%A"=="MONITOR_LOG_MAX_BYTES" set "ESP_BUILD_MONITOR_LOG_MAX_BYTES=%%B"
    if /i "%%A"=="MONITOR_CONFIG_VALID" set "ESP_BUILD_MONITOR_CONFIG_VALID=%%B"
)
if not "%ESP_BUILD_MONITOR_CONFIG_VALID%"=="1" (
    echo ERROR: Invalid monitor settings in "%CONFIG_FILE%".
    echo monitor.save_log must be true or false; max_log_size_bytes must be 1024-1073741824.
    popd
    exit /b 1
)

if /i "%~1"=="help" goto :help
if /i "%~1"=="-h" goto :help
if /i "%~1"=="--help" goto :help

if defined ESP_BUILD_IDF_PATH goto :activate_idf

where idf.py >nul 2>&1
if not errorlevel 1 (
    call idf.py --version >nul 2>&1
    if not errorlevel 1 goto :idf_ready
)

if defined IDF_PATH if exist "%IDF_PATH%\export.bat" set "ESP_BUILD_IDF_PATH=%IDF_PATH%"

if not defined ESP_BUILD_IDF_PATH (
    for /d %%V in ("C:\esp\v6*\esp-idf") do (
        if not defined ESP_BUILD_IDF_PATH if exist "%%~fV\export.bat" set "ESP_BUILD_IDF_PATH=%%~fV"
    )
)

if not defined ESP_BUILD_IDF_PATH (
    for /d %%V in ("C:\esp\v5*\esp-idf") do (
        if not defined ESP_BUILD_IDF_PATH if exist "%%~fV\export.bat" set "ESP_BUILD_IDF_PATH=%%~fV"
    )
)

if not defined ESP_BUILD_IDF_PATH (
    for /d %%V in ("C:\esp\v*") do (
        if not defined ESP_BUILD_IDF_PATH if exist "%%~fV\esp-idf\export.bat" set "ESP_BUILD_IDF_PATH=%%~fV\esp-idf"
    )
)

if not defined ESP_BUILD_IDF_PATH (
    for /d %%D in ("C:\Espressif\frameworks\esp-idf-v6*" "%USERPROFILE%\Espressif\frameworks\esp-idf-v6*") do (
        if not defined ESP_BUILD_IDF_PATH if exist "%%~fD\export.bat" set "ESP_BUILD_IDF_PATH=%%~fD"
    )
)

if not defined ESP_BUILD_IDF_PATH (
    for /d %%D in ("C:\Espressif\frameworks\esp-idf-v5*" "%USERPROFILE%\Espressif\frameworks\esp-idf-v5*") do (
        if not defined ESP_BUILD_IDF_PATH if exist "%%~fD\export.bat" set "ESP_BUILD_IDF_PATH=%%~fD"
    )
)

if not defined ESP_BUILD_IDF_PATH (
    for /d %%D in ("C:\Espressif\frameworks\esp-idf*" "%USERPROFILE%\Espressif\frameworks\esp-idf*" "%USERPROFILE%\esp\esp-idf") do (
        if not defined ESP_BUILD_IDF_PATH if exist "%%~fD\export.bat" set "ESP_BUILD_IDF_PATH=%%~fD"
    )
)

if not defined ESP_BUILD_IDF_PATH goto :idf_not_ready
if not exist "%ESP_BUILD_IDF_PATH%\export.bat" goto :idf_not_ready

:activate_idf
if not exist "%ESP_BUILD_IDF_PATH%\export.bat" goto :configured_idf_not_found
echo Activating ESP-IDF from "%ESP_BUILD_IDF_PATH%"...
if /i "%ESP_BUILD_LOGGING_ENABLED%"=="True" echo [%TIME%] Activating ESP-IDF from "%ESP_BUILD_IDF_PATH%" >> "!ESP_BUILD_LOG_FILE!"
call "%ESP_BUILD_IDF_PATH%\export.bat"
if errorlevel 1 (
    echo.
    echo ERROR: ESP-IDF environment setup failed.
    if /i "%ESP_BUILD_LOGGING_ENABLED%"=="True" echo [%TIME%] ERROR: ESP-IDF environment setup failed >> "!ESP_BUILD_LOG_FILE!"
    popd
    exit /b 1
)

:idf_ready
where idf.py >nul 2>&1
if errorlevel 1 goto :idf_not_ready
call idf.py --version >nul 2>&1
if errorlevel 1 goto :idf_not_ready

:parse_options
if "%~1"=="" goto :options_done
if /i "%~1"=="-p" goto :option_port
if /i "%~1"=="-b" goto :option_baud
if /i "%~1"=="--dry-run" goto :option_dry_run
goto :options_done

:option_port
if "%~2"=="" (
    echo ERROR: Missing serial port after -p.
    popd
    exit /b 2
)
set "ESP_BUILD_PORT=%~2"
shift
shift
goto :parse_options

:option_dry_run
set "ESP_BUILD_IDF_DRY_RUN=--dry-run"
shift
goto :parse_options

:option_baud
if "%~2"=="" (
    echo ERROR: Missing baud rate after -b.
    popd
    exit /b 2
)
set "ESP_BUILD_BAUD_OVERRIDE=%~2"
shift
shift
goto :parse_options

:options_done
if defined ESP_BUILD_IDF_DRY_RUN (
    if /i "%~1"=="flash" goto :allow_dry_run
    if /i "%~1"=="monitor" goto :allow_dry_run
    if /i "%~1"=="flash-monitor" goto :allow_dry_run
    goto :dry_run_invalid
)
if "%~1"=="" goto :default_build
if /i "%~1"=="help" goto :help
if /i "%~1"=="-h" goto :help
if /i "%~1"=="--help" goto :help
if /i "%~1"=="build" goto :explicit_build
if /i "%~1"=="clean" goto :clean
if /i "%~1"=="clean-build" goto :clean_build
if /i "%~1"=="flash" if /i "%~2"=="monitor" goto :flash_monitor
if /i "%~1"=="flash" goto :flash
if /i "%~1"=="monitor" goto :monitor
if /i "%~1"=="flash-monitor" goto :flash_monitor

:run_idf_generic
if defined ESP_BUILD_PORT (
if defined ESP_BUILD_BAUD_OVERRIDE (
    echo Running: idf.py -p %ESP_BUILD_PORT% -b %ESP_BUILD_BAUD_OVERRIDE% %1 %2 %3 %4 %5 %6 %7 %8 %9
    call idf.py -p "%ESP_BUILD_PORT%" -b "%ESP_BUILD_BAUD_OVERRIDE%" %1 %2 %3 %4 %5 %6 %7 %8 %9
) else (
    echo Running: idf.py -p %ESP_BUILD_PORT% %1 %2 %3 %4 %5 %6 %7 %8 %9
    call idf.py -p "%ESP_BUILD_PORT%" %1 %2 %3 %4 %5 %6 %7 %8 %9
)
) else if defined ESP_BUILD_BAUD_OVERRIDE (
echo Running: idf.py -b %ESP_BUILD_BAUD_OVERRIDE% %1 %2 %3 %4 %5 %6 %7 %8 %9
call idf.py -b "%ESP_BUILD_BAUD_OVERRIDE%" %1 %2 %3 %4 %5 %6 %7 %8 %9
) else (
echo Running: idf.py %1 %2 %3 %4 %5 %6 %7 %8 %9
call idf.py %1 %2 %3 %4 %5 %6 %7 %8 %9
)
goto :finish_idf_command

:finish_idf_command
set "ESP_BUILD_EXIT_CODE=%ERRORLEVEL%"
popd
exit /b %ESP_BUILD_EXIT_CODE%

:default_build
set "ESP_BUILD_USE_DEFAULT_ACTION=1"
goto :build

:explicit_build
set "ESP_BUILD_USE_DEFAULT_ACTION="
goto :build

:build
if /i "%ESP_BUILD_CLEAN_PROMPT%"=="true" if exist "build\" (
    choice /C YN /N /M "Build directory exists. Clean before build? [Y/N] "
    if errorlevel 2 goto :run_build
    call idf.py fullclean
    if errorlevel 1 goto :command_failed
)

:run_build
echo Building ESP-IDF project...
if /i "%ESP_BUILD_LOGGING_ENABLED%"=="True" (
    echo [%TIME%] ======================================================================= >> "!ESP_BUILD_LOG_FILE!"
    echo [%TIME%] Building ESP-IDF project... >> "!ESP_BUILD_LOG_FILE!"
    echo [%TIME%] ======================================================================= >> "!ESP_BUILD_LOG_FILE!"
)
if /i "%ESP_BUILD_CCACHE%"=="true" (
    if /i "%ESP_BUILD_LOGGING_ENABLED%"=="True" (
        REM Strip ANSI codes and save as clean UTF-8
        call idf.py --ccache build 2>&1 | powershell.exe -NoProfile -Command "$utf8 = New-Object System.Text.UTF8Encoding $false; $sw = New-Object System.IO.StreamWriter('!ESP_BUILD_LOG_FILE!', $true, $utf8); $input | ForEach-Object { $clean = [regex]::Replace($_, '\x1b\[[0-9;]*[a-zA-Z]|\x1b\][^\x07]*\x07|\x1b[=>]|\x08+', ''); $sw.WriteLine($clean); Write-Host $clean }; $sw.Close()"
    ) else (
        call idf.py --ccache build
    )
) else (
    if /i "%ESP_BUILD_LOGGING_ENABLED%"=="True" (
        REM Strip ANSI codes and save as clean UTF-8
        call idf.py --no-ccache build 2>&1 | powershell.exe -NoProfile -Command "$utf8 = New-Object System.Text.UTF8Encoding $false; $sw = New-Object System.IO.StreamWriter('!ESP_BUILD_LOG_FILE!', $true, $utf8); $input | ForEach-Object { $clean = [regex]::Replace($_, '\x1b\[[0-9;]*[a-zA-Z]|\x1b\][^\x07]*\x07|\x1b[=>]|\x08+', ''); $sw.WriteLine($clean); Write-Host $clean }; $sw.Close()"
    ) else (
        call idf.py --no-ccache build
    )
)
if errorlevel 1 goto :command_failed
if not defined ESP_BUILD_USE_DEFAULT_ACTION goto :success
if /i "%ESP_BUILD_DEFAULT_ACTION%"=="build" goto :success
if /i "%ESP_BUILD_DEFAULT_ACTION%"=="flash" goto :flash
if /i "%ESP_BUILD_DEFAULT_ACTION%"=="flash-monitor" (
    set "ESP_BUILD_AFTER_FLASH_MONITOR=1"
    goto :flash
)
if /i "%ESP_BUILD_DEFAULT_ACTION%"=="ask" (
    choice /C YN /N /M "Build complete. Flash to device? [Y/N] "
    if errorlevel 2 goto :success
    choice /C YN /N /M "Open serial monitor after flashing? [Y/N] "
    if not errorlevel 2 set "ESP_BUILD_AFTER_FLASH_MONITOR=1"
    goto :flash
)
echo ERROR: Unsupported workflow.default_action.
goto :command_failed

:clean
echo Cleaning generated build files. Project settings and dependencies are preserved...
call idf.py fullclean
if errorlevel 1 goto :command_failed
goto :success

:clean_build
echo Cleaning generated build files. Project settings and dependencies are preserved...
call idf.py fullclean
if errorlevel 1 goto :command_failed
set "ESP_BUILD_USE_DEFAULT_ACTION="
goto :build

:flash
if /i "%ESP_BUILD_FLASH_IMAGES%"=="false" goto :flash_without_images
set "ESP_BUILD_ACTIVE_BAUD=%ESP_BUILD_FLASH_BAUD%"
if defined ESP_BUILD_BAUD_OVERRIDE set "ESP_BUILD_ACTIVE_BAUD=%ESP_BUILD_BAUD_OVERRIDE%"
echo.
echo ================================================================================
echo Flashing firmware to device...
echo ================================================================================
if /i "%ESP_BUILD_LOGGING_ENABLED%"=="True" echo [%TIME%] Flashing firmware... >> "!ESP_BUILD_LOG_FILE!"
if defined ESP_BUILD_PORT (
    if defined ESP_BUILD_ACTIVE_BAUD (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% -p %ESP_BUILD_PORT% -b %ESP_BUILD_ACTIVE_BAUD% flash
        if /i "%ESP_BUILD_LOGGING_ENABLED%"=="True" echo [%TIME%] Running: idf.py -p %ESP_BUILD_PORT% -b %ESP_BUILD_ACTIVE_BAUD% flash >> "!ESP_BUILD_LOG_FILE!"
        call idf.py %ESP_BUILD_IDF_DRY_RUN% -p "%ESP_BUILD_PORT%" -b "%ESP_BUILD_ACTIVE_BAUD%" flash
    ) else (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% -p %ESP_BUILD_PORT% flash
        if /i "%ESP_BUILD_LOGGING_ENABLED%"=="True" echo [%TIME%] Running: idf.py -p %ESP_BUILD_PORT% flash >> "!ESP_BUILD_LOG_FILE!"
        call idf.py %ESP_BUILD_IDF_DRY_RUN% -p "%ESP_BUILD_PORT%" flash
    )
) else (
    if defined ESP_BUILD_ACTIVE_BAUD (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% -b %ESP_BUILD_ACTIVE_BAUD% flash
        if /i "%ESP_BUILD_LOGGING_ENABLED%"=="True" echo [%TIME%] Running: idf.py -b %ESP_BUILD_ACTIVE_BAUD% flash >> "!ESP_BUILD_LOG_FILE!"
        call idf.py %ESP_BUILD_IDF_DRY_RUN% -b "%ESP_BUILD_ACTIVE_BAUD%" flash
    ) else (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% flash
        if /i "%ESP_BUILD_LOGGING_ENABLED%"=="True" echo [%TIME%] Running: idf.py flash >> "!ESP_BUILD_LOG_FILE!"
        call idf.py %ESP_BUILD_IDF_DRY_RUN% flash
    )
)
if errorlevel 1 goto :command_failed
echo ================================================================================
echo Flash SUCCESSFUL!
echo ================================================================================
if /i "%ESP_BUILD_LOGGING_ENABLED%"=="True" echo [%TIME%] Flash SUCCESSFUL! >> "!ESP_BUILD_LOG_FILE!"
goto :after_flash

:flash_without_images
echo Registered additional flash images are disabled by storage.flash_images.
echo Flashing bootloader, partition table and application only...
set "ESP_BUILD_ACTIVE_BAUD=%ESP_BUILD_FLASH_BAUD%"
if defined ESP_BUILD_BAUD_OVERRIDE set "ESP_BUILD_ACTIVE_BAUD=%ESP_BUILD_BAUD_OVERRIDE%"
if defined ESP_BUILD_PORT (
    if defined ESP_BUILD_ACTIVE_BAUD (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% -p %ESP_BUILD_PORT% -b %ESP_BUILD_ACTIVE_BAUD% bootloader-flash partition-table-flash app-flash
        call idf.py %ESP_BUILD_IDF_DRY_RUN% -p "%ESP_BUILD_PORT%" -b "%ESP_BUILD_ACTIVE_BAUD%" bootloader-flash partition-table-flash app-flash
    ) else (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% -p %ESP_BUILD_PORT% bootloader-flash partition-table-flash app-flash
        call idf.py %ESP_BUILD_IDF_DRY_RUN% -p "%ESP_BUILD_PORT%" bootloader-flash partition-table-flash app-flash
    )
) else (
    if defined ESP_BUILD_ACTIVE_BAUD (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% -b %ESP_BUILD_ACTIVE_BAUD% bootloader-flash partition-table-flash app-flash
        call idf.py %ESP_BUILD_IDF_DRY_RUN% -b "%ESP_BUILD_ACTIVE_BAUD%" bootloader-flash partition-table-flash app-flash
    ) else (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% bootloader-flash partition-table-flash app-flash
        call idf.py %ESP_BUILD_IDF_DRY_RUN% bootloader-flash partition-table-flash app-flash
    )
)
if errorlevel 1 goto :command_failed
goto :after_flash

:after_flash
if not defined ESP_BUILD_AFTER_FLASH_MONITOR goto :success
goto :monitor

:monitor
set "ESP_BUILD_ACTIVE_BAUD=%ESP_BUILD_MONITOR_BAUD%"
if defined ESP_BUILD_BAUD_OVERRIDE set "ESP_BUILD_ACTIVE_BAUD=%ESP_BUILD_BAUD_OVERRIDE%"
echo.
echo ================================================================================
echo Starting Serial Monitor (Press Ctrl+] to exit)
echo ================================================================================
if /i "%ESP_BUILD_LOGGING_ENABLED%"=="True" echo [%TIME%] Starting Serial Monitor... >> "!ESP_BUILD_LOG_FILE!"
if /i "%ESP_BUILD_MONITOR_LOG_ENABLED%"=="true" if not defined ESP_BUILD_IDF_DRY_RUN goto :monitor_enable_log
goto :monitor_run

:monitor_enable_log
if not exist "%ESP_BUILD_MONITOR_SUPPORT_DIR%\sitecustomize.py" (
    echo WARNING: Monitor logging support is missing:
    echo   "%ESP_BUILD_MONITOR_SUPPORT_DIR%"
    echo Serial output will not be logged to file.
    echo Install with esp-build-manager\install-all.bat for logging support.
    echo.
)
if exist "%ESP_BUILD_MONITOR_SUPPORT_DIR%\sitecustomize.py" (
    set "ESP_BUILD_OLD_PYTHONPATH=%PYTHONPATH%"
    set "ESP_BUILD_OLD_DONTWRITEBYTECODE=%PYTHONDONTWRITEBYTECODE%"
    if defined PYTHONPATH (
        set "PYTHONPATH=%ESP_BUILD_MONITOR_SUPPORT_DIR%;%PYTHONPATH%"
    ) else (
        set "PYTHONPATH=%ESP_BUILD_MONITOR_SUPPORT_DIR%"
    )
    set "PYTHONDONTWRITEBYTECODE=1"
    set "ESP_BUILD_MONITOR_LOG_DIR=%PROJECT_DIR%.data\esp-build-logs"
    set "ESP_BUILD_MONITOR_PROJECT_DIR=%PROJECT_DIR%"
    set "ESP_BUILD_MONITOR_LOG_MAX_BYTES=%ESP_BUILD_MONITOR_LOG_MAX_BYTES%"
    set "ESP_BUILD_MONITOR_LOGGING_ACTIVE=1"
    echo Serial monitor logging enabled; limit: %ESP_BUILD_MONITOR_LOG_MAX_BYTES% bytes.
    echo Logs will be stored below .data\esp-build-logs.
    echo.
)

:monitor_run
if defined ESP_BUILD_PORT (
    if defined ESP_BUILD_ACTIVE_BAUD (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% -p %ESP_BUILD_PORT% -b %ESP_BUILD_ACTIVE_BAUD% monitor
        call idf.py %ESP_BUILD_IDF_DRY_RUN% -p "%ESP_BUILD_PORT%" -b "%ESP_BUILD_ACTIVE_BAUD%" monitor
    ) else (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% -p %ESP_BUILD_PORT% monitor
        call idf.py %ESP_BUILD_IDF_DRY_RUN% -p "%ESP_BUILD_PORT%" monitor
    )
) else (
    if defined ESP_BUILD_ACTIVE_BAUD (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% -b %ESP_BUILD_ACTIVE_BAUD% monitor
        call idf.py %ESP_BUILD_IDF_DRY_RUN% -b "%ESP_BUILD_ACTIVE_BAUD%" monitor
    ) else (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% monitor
        call idf.py %ESP_BUILD_IDF_DRY_RUN% monitor
    )
)
set "ESP_BUILD_EXIT_CODE=%ERRORLEVEL%"
if defined ESP_BUILD_MONITOR_LOGGING_ACTIVE (
    set "PYTHONPATH=%ESP_BUILD_OLD_PYTHONPATH%"
    set "PYTHONDONTWRITEBYTECODE=%ESP_BUILD_OLD_DONTWRITEBYTECODE%"
    set "ESP_BUILD_MONITOR_LOG_DIR="
    set "ESP_BUILD_MONITOR_PROJECT_DIR="
    set "ESP_BUILD_MONITOR_LOG_MAX_BYTES="
)
if not "%ESP_BUILD_EXIT_CODE%"=="0" goto :command_failed
goto :success

:flash_monitor
set "ESP_BUILD_AFTER_FLASH_MONITOR=1"
goto :flash

:allow_dry_run
goto :options_dispatch

:dry_run_invalid
echo ERROR: --dry-run must be used with flash, monitor, or flash monitor.
popd
exit /b 2

:options_dispatch
if "%~1"=="" goto :default_build
if /i "%~1"=="help" goto :help
if /i "%~1"=="-h" goto :help
if /i "%~1"=="--help" goto :help
if /i "%~1"=="build" goto :explicit_build
if /i "%~1"=="clean" goto :clean
if /i "%~1"=="clean-build" goto :clean_build
if /i "%~1"=="flash" if /i "%~2"=="monitor" goto :flash_monitor
if /i "%~1"=="flash" goto :flash
if /i "%~1"=="monitor" goto :monitor
if /i "%~1"=="flash-monitor" goto :flash_monitor
goto :run_idf_generic

:success
echo.
echo ESP-IDF command completed successfully.
popd
exit /b 0

:command_failed
set "ESP_BUILD_EXIT_CODE=%ERRORLEVEL%"
if "%ESP_BUILD_EXIT_CODE%"=="0" set "ESP_BUILD_EXIT_CODE=1"
echo.
echo ESP-IDF command failed with exit code %ESP_BUILD_EXIT_CODE%.
popd
exit /b %ESP_BUILD_EXIT_CODE%

:configured_idf_not_found
echo.
echo ERROR: The configured ESP-IDF path does not contain export.bat:
echo   "%ESP_BUILD_IDF_PATH%"
echo Correct esp_idf.path in esp-build-config.json or set it to null for automatic detection.
popd
exit /b 1

:idf_not_ready
echo.
echo ERROR: ESP-IDF could not be activated.
echo.
echo Install ESP-IDF, use its Command Prompt, or set esp_idf.path in this project's
echo esp-build-config.json to the ESP-IDF folder containing export.bat.
echo The project build script does not depend on the ESP Build Manager.
popd
exit /b 1

:help
echo ESP-IDF Build System
echo.
echo Usage: esp-build.bat [OPTIONS] [COMMAND]
echo.
echo OPTIONS:
echo   -p COMx           Set serial port (overrides config)
echo   -b BAUDRATE       Set baud rate for flash/monitor (overrides config)
echo   --dry-run         Validate flash/monitor commands without device access
echo   -h, --help        Show this help message
echo.
echo COMMANDS:
echo   (none)            Run workflow.default_action from esp-build-config.json
echo   build             Build the project (default action)
echo   clean             Clean generated files (keeps sdkconfig and dependencies)
echo   clean-build       Clean and rebuild
echo   flash             Flash firmware to device
echo   monitor           Open serial monitor
echo   flash-monitor     Flash and open serial monitor
echo.
echo CONFIGURATION:
echo   Edit esp-build-config.json to configure:
echo   - ESP-IDF path (auto-detected if null)
echo   - Serial port and baud rates
echo   - Default workflow action
echo   - Build options (ccache, clean prompt)
echo   - Logging settings
echo   - Monitor logging (save_log, max_log_size_bytes)
echo.
echo EXAMPLES:
echo   esp-build.bat                    # Run default action (build)
echo   esp-build.bat flash-monitor      # Flash and monitor
echo   esp-build.bat -p COM3 flash      # Flash to COM3
echo   esp-build.bat -b 921600 flash    # Flash at high speed
echo   esp-build.bat clean-build        # Clean rebuild
echo   esp-build.bat --dry-run flash    # Validate flash command
echo.
echo CONFIG:  esp-build-config.json
echo LOGS:    .logs\*_esp-build.log
echo.
popd
exit /b 0

@echo off
setlocal EnableExtensions

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

for /f "tokens=1,* delims==" %%A in ('powershell.exe -NoProfile -Command "$ErrorActionPreference = 'Stop'; $c = Get-Content -Raw -LiteralPath $env:CONFIG_FILE | ConvertFrom-Json; if ($c.version -ne 1) { throw 'version must be 1' }; if ($null -ne $c.esp_idf.path -and ($c.esp_idf.path -isnot [string] -or [string]::IsNullOrWhiteSpace($c.esp_idf.path))) { throw 'esp_idf.path must be a non-empty path string or null' }; if ($null -ne $c.serial.port -and ($c.serial.port -isnot [string] -or [string]::IsNullOrWhiteSpace($c.serial.port))) { throw 'serial.port must be a non-empty string or null' }; foreach ($key in @('flash_baudrate','monitor_baudrate')) { $value = $c.serial.$key; if ($null -ne $value -and ($value -isnot [int] -or $value -lt 1 -or $value -gt 2000000)) { throw ('serial.' + $key + ' must be an integer between 1 and 2000000 or null') } }; if (@('build','flash','flash-monitor','ask') -notcontains $c.workflow.default_action) { throw 'workflow.default_action must be build, flash, flash-monitor, or ask' }; if ($c.workflow.clean_build_prompt -isnot [bool] -or $c.build.ccache -isnot [bool] -or $c.storage.flash_images -isnot [bool]) { throw 'workflow.clean_build_prompt, build.ccache, and storage.flash_images must be true or false' }; 'IDF_PATH=' + [string]$c.esp_idf.path; 'PORT=' + [string]$c.serial.port; 'FLASH_BAUD=' + [string]$c.serial.flash_baudrate; 'MONITOR_BAUD=' + [string]$c.serial.monitor_baudrate; 'DEFAULT_ACTION=' + [string]$c.workflow.default_action; 'CLEAN_PROMPT=' + [string]$c.workflow.clean_build_prompt; 'FLASH_IMAGES=' + [string]$c.storage.flash_images; 'CCACHE=' + [string]$c.build.ccache; 'CONFIG_VALID=1'"') do (
    if /i "%%A"=="IDF_PATH" set "ESP_BUILD_IDF_PATH=%%B"
    if /i "%%A"=="PORT" set "ESP_BUILD_PORT=%%B"
    if /i "%%A"=="FLASH_BAUD" set "ESP_BUILD_FLASH_BAUD=%%B"
    if /i "%%A"=="MONITOR_BAUD" set "ESP_BUILD_MONITOR_BAUD=%%B"
    if /i "%%A"=="DEFAULT_ACTION" set "ESP_BUILD_DEFAULT_ACTION=%%B"
    if /i "%%A"=="CLEAN_PROMPT" set "ESP_BUILD_CLEAN_PROMPT=%%B"
    if /i "%%A"=="FLASH_IMAGES" set "ESP_BUILD_FLASH_IMAGES=%%B"
    if /i "%%A"=="CCACHE" set "ESP_BUILD_CCACHE=%%B"
    if /i "%%A"=="CONFIG_VALID" set "ESP_BUILD_CONFIG_VALID=%%B"
)
if not "%ESP_BUILD_CONFIG_VALID%"=="1" (
    echo ERROR: Invalid or unsupported settings in "%CONFIG_FILE%".
    echo Check esp-build-config.json against the example configuration.
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
call "%ESP_BUILD_IDF_PATH%\export.bat"
if errorlevel 1 (
    echo.
    echo ERROR: ESP-IDF environment setup failed.
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
if /i "%ESP_BUILD_CCACHE%"=="true" (
    call idf.py --ccache build
) else (
    call idf.py --no-ccache build
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
if defined ESP_BUILD_PORT (
    if defined ESP_BUILD_ACTIVE_BAUD (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% -p %ESP_BUILD_PORT% -b %ESP_BUILD_ACTIVE_BAUD% flash
        call idf.py %ESP_BUILD_IDF_DRY_RUN% -p "%ESP_BUILD_PORT%" -b "%ESP_BUILD_ACTIVE_BAUD%" flash
    ) else (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% -p %ESP_BUILD_PORT% flash
        call idf.py %ESP_BUILD_IDF_DRY_RUN% -p "%ESP_BUILD_PORT%" flash
    )
) else (
    if defined ESP_BUILD_ACTIVE_BAUD (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% -b %ESP_BUILD_ACTIVE_BAUD% flash
        call idf.py %ESP_BUILD_IDF_DRY_RUN% -b "%ESP_BUILD_ACTIVE_BAUD%" flash
    ) else (
        echo Running: idf.py %ESP_BUILD_IDF_DRY_RUN% flash
        call idf.py %ESP_BUILD_IDF_DRY_RUN% flash
    )
)
if errorlevel 1 goto :command_failed
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
if errorlevel 1 goto :command_failed
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
echo Usage: esp-build.bat [-p COMx] [-b BAUD] [--dry-run] [build^|clean^|clean-build^|flash^|flash monitor^|monitor^|idf.py command]
echo.
echo With no command, runs workflow.default_action from esp-build-config.json.
echo clean and clean-build preserve sdkconfig, dependencies.lock and managed_components.
echo storage.flash_images controls whether registered extra images are included while flashing.
echo --dry-run validates flash or monitor commands without accessing the device.
popd
exit /b 0

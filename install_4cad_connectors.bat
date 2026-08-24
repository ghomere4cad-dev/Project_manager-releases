@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: =============================================================================
:: install_4cad_connectors.bat
::
:: Installe les outils 4CAD sur un poste utilisateur :
::   1. Node.js LTS (si absent)
::   2. Salesforce CLI (sf)
::
:: Variante Project Manager : copie adaptee de l'original fourni par l'equipe
:: Data (qui installe aussi "uv", un outil de dev Python sans utilite pour un
:: collegue qui ne fait qu'utiliser l'appli -- retire ici pour ne pas faire
:: echouer tout le script sur un outil dont Project Manager n'a jamais besoin).
::
:: Usage :
::   install_4cad_connectors.bat
::   install_4cad_connectors.bat /silent
::
:: Codes retour :
::   0  = succes
::   10 = winget introuvable
::   11 = echec installation Node.js
::   12 = npm introuvable apres installation
::   20 = echec installation Salesforce CLI
::   21 = sf introuvable apres installation
:: =============================================================================

set "SILENT=0"
if /I "%~1"=="/silent" set "SILENT=1"

for /f %%I in ('powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMdd_HHmmss')"') do set "TS=%%I"

set "LOGDIR=%TEMP%\4cad_tools_install"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
set "LOGFILE=%LOGDIR%\install_4cad_tools_%TS%.log"

call :log "============================================================"
call :log "Demarrage installation 4CAD tools"
call :log "Machine  : %COMPUTERNAME%"
call :log "Utilisateur : %USERNAME%"
call :log "Log      : %LOGFILE%"
call :log "============================================================"

if "%SILENT%"=="0" (
    echo.
    echo  ============================================================
    echo   Installation des outils 4CAD
    echo  ============================================================
    echo.
    echo   Journal : %LOGFILE%
    echo.
)

call :ensure_node
if errorlevel 1 exit /b %errorlevel%

call :ensure_sf
if errorlevel 1 exit /b %errorlevel%

call :log "Installation terminee avec succes"

if "%SILENT%"=="0" (
    echo.
    echo  ============================================================
    echo   Installation terminee avec succes
    echo  ============================================================
    echo.
    echo   Versions detectees :
    call :print_version "npm.cmd" "--version"
    call :print_version "sf.cmd" "--version"
    echo.
    echo   Etape suivante - connexion Salesforce, une seule fois par machine :
    echo.
    echo     sf org login web --instance-url https://4cad.my.salesforce.com --alias 4cad-sf
    echo.
    echo   Etape suivante - configuration des projets :
    echo.
    echo     Placez setup_project.bat a la racine du projet puis executez-le.
    echo.
    echo   Si un nouveau terminal ne voit pas encore les outils :
    echo     fermez le terminal puis rouvrez-le.
    echo.
    pause
)
exit /b 0


:: =============================================================================
:: Installation Node.js / npm
:: =============================================================================

:ensure_node
call :log "[NODE] Verification npm"
call :find_npm
if not errorlevel 1 (
    call :log "[NODE] npm deja disponible"
    exit /b 0
)

call :log "[NODE] npm absent - installation Node.js LTS via winget"
if "%SILENT%"=="0" echo [1/2] Installation Node.js LTS...

where winget >nul 2>&1
if errorlevel 1 (
    call :log "[NODE][ERREUR] winget introuvable"
    if "%SILENT%"=="0" (
        echo.
        echo ERREUR : winget est introuvable sur ce poste.
        echo Installez Node.js LTS manuellement : https://nodejs.org
        echo Puis relancez ce script.
        echo.
        pause
    )
    exit /b 10
)

winget install --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements >> "%LOGFILE%" 2>&1
if errorlevel 1 (
    call :log "[NODE][ERREUR] echec winget install OpenJS.NodeJS.LTS"
    if "%SILENT%"=="0" (
        echo.
        echo ERREUR : echec installation Node.js via winget.
        echo Voir le log : %LOGFILE%
        echo.
        pause
    )
    exit /b 11
)

:: Ajout des chemins probables a la session
if exist "%ProgramFiles%\nodejs\npm.cmd" call :add_session_path "%ProgramFiles%\nodejs"
if exist "%ProgramFiles(x86)%\nodejs\npm.cmd" call :add_session_path "%ProgramFiles(x86)%\nodejs"

:: Ajout persistant du PATH utilisateur si besoin
if exist "%ProgramFiles%\nodejs\npm.cmd" call :ensure_user_path "%ProgramFiles%\nodejs"
if exist "%ProgramFiles(x86)%\nodejs\npm.cmd" call :ensure_user_path "%ProgramFiles(x86)%\nodejs"

call :find_npm
if not errorlevel 1 (
    call :log "[NODE] npm disponible apres installation"
    exit /b 0
)

call :log "[NODE][ERREUR] npm reste introuvable apres installation"
if "%SILENT%"=="0" (
    echo.
    echo ERREUR : npm reste introuvable apres installation de Node.js.
    echo Fermez cette fenetre, ouvrez un nouveau terminal, puis relancez le script.
    echo Log : %LOGFILE%
    echo.
    pause
)
exit /b 12


:: =============================================================================
:: Installation Salesforce CLI
:: =============================================================================

:ensure_sf
call :log "[SF] Verification Salesforce CLI"
call :find_sf
if not errorlevel 1 (
    call :log "[SF] Salesforce CLI deja disponible"
    exit /b 0
)

if "%SILENT%"=="0" echo [2/2] Installation Salesforce CLI...

call :find_npm
if errorlevel 1 (
    call :log "[SF][ERREUR] npm introuvable avant installation Salesforce CLI"
    if "%SILENT%"=="0" (
        echo.
        echo ERREUR : npm est introuvable, impossible d'installer Salesforce CLI.
        echo Voir le log : %LOGFILE%
        echo.
        pause
    )
    exit /b 20
)

call :log "[SF] npm install --global @salesforce/cli"
call npm.cmd install --global @salesforce/cli >> "%LOGFILE%" 2>&1
if errorlevel 1 (
    call :log "[SF][ERREUR] echec npm install @salesforce/cli"
    if "%SILENT%"=="0" (
        echo.
        echo ERREUR : echec installation Salesforce CLI via npm.
        echo Voir le log : %LOGFILE%
        echo.
        pause
    )
    exit /b 20
)

:: Recuperation du prefix npm global
set "NPM_PREFIX="
for /f "usebackq delims=" %%I in (`npm.cmd config get prefix 2^>nul`) do set "NPM_PREFIX=%%I"
call :log "[SF] NPM_PREFIX=%NPM_PREFIX%"

if defined NPM_PREFIX (
    call :ensure_user_path "%NPM_PREFIX%"
    call :add_session_path "%NPM_PREFIX%"
)

:: Fallback courant Windows
if exist "%APPDATA%\npm\sf.cmd" (
    call :ensure_user_path "%APPDATA%\npm"
    call :add_session_path "%APPDATA%\npm"
)

call :find_sf
if not errorlevel 1 (
    call :log "[SF] Salesforce CLI disponible apres installation"
    exit /b 0
)

call :log "[SF][ERREUR] sf reste introuvable apres installation"
if "%SILENT%"=="0" (
    echo.
    echo ERREUR : sf reste introuvable apres installation.
    echo Fermez cette fenetre, ouvrez un nouveau terminal, puis relancez check_4cad_connectors.bat
    echo Log : %LOGFILE%
    echo.
    pause
)
exit /b 21


:: =============================================================================
:: Fonctions utilitaires
:: =============================================================================

:find_npm
where npm.cmd >nul 2>&1 && exit /b 0
where npm >nul 2>&1 && exit /b 0
if exist "%ProgramFiles%\nodejs\npm.cmd" exit /b 0
if exist "%ProgramFiles(x86)%\nodejs\npm.cmd" exit /b 0
exit /b 1

:find_sf
where sf.cmd >nul 2>&1 && exit /b 0
where sf >nul 2>&1 && exit /b 0
if exist "%APPDATA%\npm\sf.cmd" exit /b 0
exit /b 1

:add_session_path
set "TARGET_PATH=%~1"
if "%TARGET_PATH%"=="" exit /b 0

echo ;!PATH!; | find /I ";%TARGET_PATH%;" >nul
if errorlevel 1 (
    set "PATH=!PATH!;%TARGET_PATH%"
    call :log "[PATH][SESSION] ajout %TARGET_PATH%"
)
exit /b 0

:ensure_user_path
set "TARGET_PATH=%~1"
if "%TARGET_PATH%"=="" exit /b 0

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$target='%TARGET_PATH%';" ^
  "$current=[Environment]::GetEnvironmentVariable('Path','User');" ^
  "$parts=@();" ^
  "if($current){ $parts=$current -split ';' ^| Where-Object { $_ -and $_.Trim() -ne '' } }" ^
  "if($parts -notcontains $target){" ^
  "  $new=(@($parts)+$target) -join ';';" ^
  "  [Environment]::SetEnvironmentVariable('Path',$new,'User')" ^
  "}" >> "%LOGFILE%" 2>&1

if errorlevel 1 (
    call :log "[PATH][USER][WARN] echec ajout %TARGET_PATH%"
) else (
    call :log "[PATH][USER] ajout %TARGET_PATH%"
)
exit /b 0

:print_version
set "CMD=%~1"
set "ARG=%~2"
where %CMD% >nul 2>&1
if errorlevel 1 (
    echo   - %CMD% : introuvable
    exit /b 0
)
for /f "usebackq delims=" %%I in (`%CMD% %ARG% 2^>nul`) do (
    echo   - %CMD% : %%I
    goto :eof
)
echo   - %CMD% : version non lue
exit /b 0

:log
echo [%DATE% %TIME%] %~1>> "%LOGFILE%"
if "%SILENT%"=="0" echo %~1
exit /b 0

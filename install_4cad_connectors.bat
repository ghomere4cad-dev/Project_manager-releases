@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: =============================================================================
:: install_4cad_connectors.bat
::
:: Installe les outils 4CAD sur un poste utilisateur :
::   1. Node.js LTS (si absent OU defectueux)
::   2. Salesforce CLI (sf)
::
:: Variante Project Manager : copie adaptee de l'original fourni par l'equipe
:: Data (qui installe aussi "uv", un outil de dev Python sans utilite pour un
:: collegue qui ne fait qu'utiliser l'appli -- retire ici pour ne pas faire
:: echouer tout le script sur un outil dont Project Manager n'a jamais besoin).
::
:: Verification REELLE : un outil n'est "disponible" que si on peut l'EXECUTER
:: (npm.cmd --version / sf.cmd --version), pas seulement si un fichier existe.
:: Cas corrige : dossier "Program Files\nodejs" present (installation Node.js
:: avortee ou PATH non mis a jour) -> l'ancienne version annoncait "npm deja
:: disponible" puis echouait sur "npm.cmd n'est pas reconnu". Desormais : on
:: tente d'abord de reparer le PATH, puis on REINSTALLE Node.js (winget --force,
:: sinon MSI officiel nodejs.org) et on re-verifie l'execution.
::
:: Usage :
::   install_4cad_connectors.bat
::   install_4cad_connectors.bat /silent
::   install_4cad_connectors.bat /reinstall        (force la reinstallation de Node.js)
::   (les deux options sont combinables)
::
:: Codes retour :
::   0  = succes
::   10 = winget introuvable ET telechargement MSI impossible
::   11 = echec installation Node.js
::   12 = npm inutilisable apres installation
::   20 = echec installation Salesforce CLI
::   21 = sf inutilisable apres installation
:: =============================================================================

set "SILENT=0"
set "REINSTALL=0"
for %%A in (%*) do (
    if /I "%%~A"=="/silent" set "SILENT=1"
    if /I "%%~A"=="/reinstall" set "REINSTALL=1"
)

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
    echo   Installation terminee avec succes - verification reussie
    echo  ============================================================
    echo.
    echo   Versions detectees :
    call :print_version "node.exe" "--version"
    call :print_version "npm.cmd" "--version"
    call :print_version "sf.cmd" "--version"
    echo.
    echo   Etape suivante - connexion Salesforce, une seule fois par machine :
    echo.
    echo     sf org login web --instance-url https://4cad.my.salesforce.com --alias 4cad-sf
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
call :log "[NODE] Verification npm (execution reelle)"
if "%REINSTALL%"=="1" (
    call :log "[NODE] reinstallation demandee (/reinstall)"
    goto :node_install
)
call :find_npm
if not errorlevel 1 (
    call :log "[NODE] npm fonctionnel"
    exit /b 0
)
call :log "[NODE] npm absent ou inutilisable - reinstallation Node.js LTS"

:node_install
if "%SILENT%"=="0" echo [1/2] Installation Node.js LTS...

set "NODE_OK=0"
where winget >nul 2>&1
if not errorlevel 1 (
    call :log "[NODE] winget install OpenJS.NodeJS.LTS --force"
    winget install --id OpenJS.NodeJS.LTS --force --silent --accept-package-agreements --accept-source-agreements >> "%LOGFILE%" 2>&1
    if not errorlevel 1 set "NODE_OK=1"
    if "!NODE_OK!"=="0" call :log "[NODE][WARN] echec winget - essai via le MSI nodejs.org"
) else (
    call :log "[NODE][WARN] winget introuvable - essai via le MSI nodejs.org"
)

if "!NODE_OK!"=="0" (
    call :install_node_msi
    if not errorlevel 1 set "NODE_OK=1"
)

if "!NODE_OK!"=="0" (
    call :log "[NODE][ERREUR] installation Node.js impossible (winget et MSI)"
    if "%SILENT%"=="0" (
        echo.
        echo ERREUR : installation de Node.js impossible.
        echo Installez Node.js LTS manuellement : https://nodejs.org
        echo Puis relancez ce script.
        echo Voir le log : %LOGFILE%
        echo.
        pause
    )
    exit /b 11
)

:: Chemins probables : ajout a la session ET au PATH utilisateur, puis verification par execution
call :find_npm
if not errorlevel 1 (
    call :log "[NODE] npm fonctionnel apres installation"
    exit /b 0
)

call :log "[NODE][ERREUR] npm reste inutilisable apres installation"
if "%SILENT%"=="0" (
    echo.
    echo ERREUR : npm reste inutilisable apres installation de Node.js.
    echo Fermez cette fenetre, ouvrez un nouveau terminal, puis relancez le script.
    echo Log : %LOGFILE%
    echo.
    pause
)
exit /b 12


:: MSI officiel Node.js LTS (nodejs.org) -- repli quand winget est absent ou en echec.
:: Elevation demandee par PowerShell (installation pour tous les utilisateurs).
:install_node_msi
set "NODE_MSI=%TEMP%\4cad_node_lts.msi"
call :log "[NODE] telechargement du MSI Node.js LTS (nodejs.org)"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $i=@((Invoke-RestMethod 'https://nodejs.org/dist/index.json') | Where-Object { $_.lts })[0]; $u='https://nodejs.org/dist/'+$i.version+'/node-'+$i.version+'-x64.msi'; Invoke-WebRequest $u -OutFile '%NODE_MSI%' -UseBasicParsing; Write-Output ('MSI telecharge : '+$u)" >> "%LOGFILE%" 2>&1
if errorlevel 1 (
    call :log "[NODE][ERREUR] telechargement du MSI impossible"
    exit /b 1
)
call :log "[NODE] installation du MSI (une confirmation administrateur peut s'afficher)"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=Start-Process msiexec.exe -ArgumentList '/i','%NODE_MSI%','/qn','/norestart' -Verb RunAs -Wait -PassThru; exit $p.ExitCode" >> "%LOGFILE%" 2>&1
if errorlevel 1 (
    call :log "[NODE][ERREUR] echec installation du MSI"
    exit /b 1
)
exit /b 0


:: =============================================================================
:: Installation Salesforce CLI
:: =============================================================================

:ensure_sf
call :log "[SF] Verification Salesforce CLI (execution reelle)"
call :find_sf
if not errorlevel 1 (
    call :log "[SF] Salesforce CLI fonctionnel"
    exit /b 0
)

if "%SILENT%"=="0" echo [2/2] Installation Salesforce CLI...

call :find_npm
if errorlevel 1 (
    call :log "[SF][ERREUR] npm inutilisable avant installation Salesforce CLI"
    if "%SILENT%"=="0" (
        echo.
        echo ERREUR : npm est inutilisable, impossible d'installer Salesforce CLI.
        echo Voir le log : %LOGFILE%
        echo.
        pause
    )
    exit /b 20
)

call :log "[SF] npm install --global @salesforce/cli"
call npm.cmd install --global @salesforce/cli >> "%LOGFILE%" 2>&1
if errorlevel 1 (
    call :log "[SF][WARN] premier essai en echec - nettoyage du cache npm puis nouvel essai"
    call npm.cmd cache clean --force >> "%LOGFILE%" 2>&1
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
    call :log "[SF] Salesforce CLI fonctionnel apres installation"
    exit /b 0
)

call :log "[SF][ERREUR] sf reste inutilisable apres installation"
if "%SILENT%"=="0" (
    echo.
    echo ERREUR : sf reste inutilisable apres installation.
    echo Fermez cette fenetre, ouvrez un nouveau terminal, puis relancez l'installation.
    echo Log : %LOGFILE%
    echo.
    pause
)
exit /b 21


:: =============================================================================
:: Fonctions utilitaires
:: =============================================================================

:: npm est "disponible" seulement s'il S'EXECUTE. Sinon, on cherche npm.cmd dans les
:: dossiers Node.js habituels et on ajoute ce dossier au PATH (session + utilisateur).
:find_npm
call npm.cmd --version >nul 2>&1
if not errorlevel 1 exit /b 0
for %%D in ("%ProgramFiles%\nodejs" "%ProgramFiles(x86)%\nodejs" "%LOCALAPPDATA%\Programs\nodejs") do (
    if exist "%%~D\npm.cmd" (
        call :add_session_path "%%~D"
        call npm.cmd --version >nul 2>&1
        if not errorlevel 1 (
            call :ensure_user_path "%%~D"
            exit /b 0
        )
    )
)
exit /b 1

:find_sf
call sf.cmd --version >nul 2>&1
if not errorlevel 1 exit /b 0
if exist "%APPDATA%\npm\sf.cmd" (
    call :add_session_path "%APPDATA%\npm"
    call sf.cmd --version >nul 2>&1
    if not errorlevel 1 (
        call :ensure_user_path "%APPDATA%\npm"
        exit /b 0
    )
)
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

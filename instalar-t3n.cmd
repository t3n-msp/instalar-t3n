@echo off
REM ============================================================================
REM  instalar-t3n.cmd: prepara o PC para o plugin t3n-1password do Claude.
REM  ----------------------------------------------------------------------------
REM  Por usuario, sem admin e sem PowerShell. Instala o que faltar:
REM    1. Git for Windows (o Claude roda os comandos no Git Bash);
REM    2. Claude desktop (pelo navegador: o site recusa downloads fora dele);
REM    3. Claude Code CLI (pelo instalador oficial para cmd).
REM  Depois: abra o Claude, entre com a conta da empresa e, na aba Code, digite
REM  /1password-instalar. O resto (1Password, CLI, Python do kit) e com o plugin.
REM
REM  Generico, sem segredo e sem dado de cliente ou de pessoa: e publico (D38).
REM  Uso: instalar-t3n.cmd                 instala o que faltar
REM       instalar-t3n.cmd /conferir       so baixa e confere o Git, sem instalar
REM       instalar-t3n.cmd /proxy <url>    usa este proxy (ex.: http://proxy:3128/)
REM ============================================================================

setlocal
set "CONFERIR="
set "PROXY="
:args
if "%~1"=="" goto :args_fim
if /i "%~1"=="/conferir" (set "CONFERIR=1" & shift & goto :args)
if /i "%~1"=="/proxy" (set "PROXY=%~2" & shift & shift & goto :args)
echo Opcao desconhecida: %~1
exit /b 2
:args_fim
set "TMPDIR=%TEMP%\instalar-t3n-%RANDOM%%RANDOM%"
mkdir "%TMPDIR%" || exit /b 1

REM Rede: o curl nao usa o proxy do Windows sozinho. Vale o /proxy; senao o do ambiente;
REM senao o configurado no Windows (Internet Settings do usuario), so neste processo.
if not defined PROXY if defined HTTPS_PROXY goto :rede_ok
if not defined PROXY call :proxy_do_windows
if not defined PROXY goto :rede_ok
set "HTTP_PROXY=%PROXY%"
set "HTTPS_PROXY=%PROXY%"
if not defined NO_PROXY set "NO_PROXY=localhost,127.0.0.1"
echo Usando o proxy %PROXY%
:rede_ok

curl --version >nul 2>&1 || (echo curl nao encontrado: precisa do Windows 10 1803 ou mais novo. & goto :falha)

REM --- 1. Git for Windows -----------------------------------------------------
set "GITBASH="
if defined CLAUDE_CODE_GIT_BASH_PATH if exist "%CLAUDE_CODE_GIT_BASH_PATH%" set "GITBASH=%CLAUDE_CODE_GIT_BASH_PATH%"
if not defined GITBASH if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "GITBASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if not defined GITBASH if exist "%ProgramFiles%\Git\bin\bash.exe" set "GITBASH=%ProgramFiles%\Git\bin\bash.exe"
if defined GITBASH if not defined CONFERIR (
    echo SKIP: Git ja instalado ^(%GITBASH%^)
    goto :claude_desktop
)

echo === Git for Windows: procurando a versao mais nova
set "JSON=%TMPDIR%\git-release.json"
call :baixar "https://api.github.com/repos/git-for-windows/git/releases/latest" "%JSON%" || goto :falha
REM O "." do findstr casa as aspas do JSON, que o cmd nao deixa escrever no padrao.
set "PADRAO=name.: .Git-[0-9.]*-64-bit\.exe"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "PADRAO=name.: .Git-[0-9.]*-arm64\.exe"

REM O JSON da API vem com um campo por linha: o "digest" do asset vem depois do "name".
REM Com : e aspas como separadores, a linha 12:  "name": "Git-x.exe", vira
REM 12 / espacos / name / espaco / Git-x.exe / , (tokens 1 e 5).
set "LN="
for /f tokens^=1^,5^ delims^=^:^" %%n in ('findstr /n /r /c:"%PADRAO%" "%JSON%"') do (
    set "LN=%%n"
    set "NOME=%%o"
)
if not defined LN (echo Nao achei o instalador do Git na release. & goto :falha)
set "SHA="
for /f tokens^=1^,6^ delims^=^:^" %%n in ('findstr /n /r /c:"digest.: .sha256:" "%JSON%"') do (
    if not defined SHA if %%n GTR %LN% set "SHA=%%o"
)
if not defined SHA (echo A release do Git nao publicou o SHA-256. & goto :falha)
for /f tokens^=4^ delims^=^:^" %%a in ('findstr /r /c:"tag_name.:" "%JSON%"') do set "TAG=%%a"

echo Baixando %NOME% (%TAG%)
call :baixar "https://github.com/git-for-windows/git/releases/download/%TAG%/%NOME%" "%TMPDIR%\%NOME%" || goto :falha
call :conferir_sha "%TMPDIR%\%NOME%" "%SHA%" || goto :falha
echo OK: SHA-256 confere com o publicado
if defined CONFERIR goto :fim

echo Instalando o Git em %LOCALAPPDATA%\Programs\Git ...
"%TMPDIR%\%NOME%" /VERYSILENT /NORESTART /NOCANCEL /SP- /SUPPRESSMSGBOXES "/DIR=%LOCALAPPDATA%\Programs\Git"
if errorlevel 1 (echo FAIL: instalador do Git & goto :falha)
set "GITBASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
echo OK: Git instalado

:claude_desktop
REM --- 2. Claude desktop ------------------------------------------------------
set "TEMCLAUDE="
if exist "%LOCALAPPDATA%\AnthropicClaude\claude.exe" set "TEMCLAUDE=1"
for /d %%d in ("%LOCALAPPDATA%\Packages\claude.ai-*" "%LOCALAPPDATA%\Packages\Anthropic*") do set "TEMCLAUDE=1"
if defined TEMCLAUDE (
    echo SKIP: Claude desktop ja instalado
) else (
    echo === Claude desktop: abrindo a pagina de download no navegador
    start "" "https://claude.ai/download"
    echo Baixe e instale o Claude para Windows. Depois volte aqui.
    pause
)

REM --- 3. Claude Code CLI -----------------------------------------------------
where claude >nul 2>&1 && (echo SKIP: Claude Code CLI ja instalado & goto :pronto)
if exist "%USERPROFILE%\.local\bin\claude.exe" (echo SKIP: Claude Code CLI ja instalado & goto :pronto)
echo === Claude Code CLI
call :baixar "https://claude.ai/install.cmd" "%TMPDIR%\install.cmd" || goto :falha
pushd "%TMPDIR%"
call "%TMPDIR%\install.cmd"
popd
if errorlevel 1 (echo FAIL: Claude Code CLI & goto :falha)

:pronto
echo.
echo Pronto. Agora:
echo   1. abra o Claude e entre com a conta da sua empresa;
echo   2. na aba Code, digite /1password-instalar
echo      (o plugin t3n-1password chega pela sua organizacao no Claude).
goto :fim

REM --- Rotinas ----------------------------------------------------------------

:proxy_do_windows
REM So o formato simples "host:porta"; com um proxy por protocolo ou PAC, use /proxy.
set "CHAVE=HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
reg query "%CHAVE%" /v ProxyEnable 2>nul | findstr /r /c:"0x1$" >nul || exit /b 0
set "SERVIDOR="
for /f "tokens=2,*" %%a in ('reg query "%CHAVE%" /v ProxyServer 2^>nul ^| findstr /i "ProxyServer"') do set "SERVIDOR=%%b"
if not defined SERVIDOR exit /b 0
echo %SERVIDOR%| findstr "=" >nul && exit /b 0
set "PROXY=http://%SERVIDOR%/"
set "EXCECOES="
for /f "tokens=2,*" %%a in ('reg query "%CHAVE%" /v ProxyOverride 2^>nul ^| findstr /i "ProxyOverride"') do set "EXCECOES=%%b"
if not defined EXCECOES exit /b 0
set "EXCECOES=%EXCECOES:<local>=localhost%"
set "NO_PROXY=%EXCECOES:;=,%,127.0.0.1"
exit /b 0

:baixar
REM O schannel do curl falha quando nao alcanca o servidor de revogacao (comum
REM atras de proxy); ai tenta de novo pulando so essa checagem.
curl -fsSL "%~1" -o "%~2" 2>nul && exit /b 0
curl -fsSL --ssl-revoke-best-effort "%~1" -o "%~2"
exit /b %errorlevel%

:conferir_sha
set "ATUAL="
for /f "skip=1 tokens=* delims=" %%h in ('certutil -hashfile "%~1" SHA256') do (
    if not defined ATUAL set "ATUAL=%%h"
)
set "ATUAL=%ATUAL: =%"
if /i "%ATUAL%"=="%~2" exit /b 0
echo O SHA-256 de %~nx1 nao confere com o publicado. Download descartado.
del "%~1" >nul 2>&1
exit /b 1

:falha
echo.
echo Nao concluido. Rode de novo; se persistir, fale com o suporte de TI.
rmdir /s /q "%TMPDIR%" >nul 2>&1
endlocal
exit /b 1

:fim
rmdir /s /q "%TMPDIR%" >nul 2>&1
endlocal
exit /b 0

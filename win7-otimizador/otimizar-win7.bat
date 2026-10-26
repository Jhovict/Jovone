@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Otimizador Windows 7
color 0A

:: ============================================================
::  Otimizador Windows 7
::  Executar como Administrador (botao direito > Executar como
::  administrador). Cria ponto de restauracao antes de mexer.
::  Textos sem acento de proposito: o console do Win7 nao
::  mostra UTF-8 direito.
:: ============================================================

net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo  [ERRO] Este script precisa ser executado como Administrador.
    echo  Clique com o botao direito no arquivo e escolha
    echo  "Executar como administrador".
    echo.
    pause
    exit /b 1
)

set "DIR=%~dp0"
set "LOG=%DIR%otimizar-win7.log"
echo ==== %date% %time% ==== >> "%LOG%"

:menu
cls
echo.
echo  ==========================================================
echo                 OTIMIZADOR  -  WINDOWS 7
echo  ==========================================================
echo.
echo   1. Otimizacao rapida (recomendado: 2 a 7 abaixo)
echo.
echo   2. Criar ponto de restauracao
echo   3. Limpar arquivos temporarios, cache e lixeira
echo   4. Limpeza de disco do Windows (cleanmgr automatico)
echo   5. Efeitos visuais para melhor desempenho
echo   6. Plano de energia "Alto desempenho"
echo   7. Desativar servicos desnecessarios
echo   8. Ajustes de rede (limpar DNS, resetar Winsock)
echo.
echo   9. Desfragmentar disco C: (SOMENTE HD, nao use em SSD)
echo  10. Ajustes para SSD (desliga desfrag. agendada e Superfetch)
echo  11. Desativar hibernacao (libera varios GB no C:)
echo  12. Verificar arquivos do sistema (sfc /scannow, demorado)
echo  13. Ver programas que iniciam com o Windows
echo.
echo  14. Desfazer ajustes (visual, energia, servicos)
echo   0. Sair
echo.
set "op="
set /p "op=  Escolha uma opcao: "

if "%op%"=="1"  goto rapida
if "%op%"=="2"  call :restauracao & goto fim
if "%op%"=="3"  call :temporarios & goto fim
if "%op%"=="4"  call :cleanmgr & goto fim
if "%op%"=="5"  call :visual & goto fim
if "%op%"=="6"  call :energia & goto fim
if "%op%"=="7"  call :servicos & goto fim
if "%op%"=="8"  call :rede & goto fim
if "%op%"=="9"  call :desfrag & goto fim
if "%op%"=="10" call :ssd & goto fim
if "%op%"=="11" call :hibernacao & goto fim
if "%op%"=="12" call :sfc & goto fim
if "%op%"=="13" call :inicializacao & goto fim
if "%op%"=="14" call :desfazer & goto fim
if "%op%"=="0"  exit /b 0
goto menu

:rapida
call :restauracao
call :temporarios
call :cleanmgr
call :visual
call :energia
call :servicos
echo.
echo  ----------------------------------------------------------
echo   Otimizacao rapida concluida.
echo   Reinicie o computador para aplicar tudo.
echo  ----------------------------------------------------------
goto fim

:fim
echo.
pause
goto menu

:: ------------------------------------------------------------
:restauracao
echo.
echo  [*] Criando ponto de restauracao...
sc config srservice start= auto >nul 2>&1
wmic /namespace:\\root\default path SystemRestore call CreateRestorePoint "Antes do Otimizador Win7", 100, 7 >nul 2>&1
if errorlevel 1 (
    echo  [!] Nao foi possivel criar. Verifique se a Restauracao do
    echo      Sistema esta ativada no disco C: ^(Painel de Controle ^>
    echo      Sistema ^> Protecao do sistema^).
    echo restauracao: falhou >> "%LOG%"
) else (
    echo  [OK] Ponto de restauracao criado.
    echo restauracao: ok >> "%LOG%"
)
exit /b

:: ------------------------------------------------------------
:temporarios
echo.
echo  [*] Limpando temporarios do usuario...
call :limparpasta "%TEMP%"
echo  [*] Limpando temporarios do Windows...
call :limparpasta "%SystemRoot%\Temp"
echo  [*] Limpando cache do Internet Explorer...
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8 >nul 2>&1
echo  [*] Limpando cache de miniaturas...
taskkill /f /im explorer.exe >nul 2>&1
del /f /q /a "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
start explorer.exe
echo  [*] Limpando downloads antigos do Windows Update...
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
call :limparpasta "%SystemRoot%\SoftwareDistribution\Download"
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
echo  [*] Limpando relatorios de erro...
call :limparpasta "%ProgramData%\Microsoft\Windows\WER\ReportArchive"
call :limparpasta "%ProgramData%\Microsoft\Windows\WER\ReportQueue"
echo  [*] Esvaziando a lixeira...
rd /s /q "%SystemDrive%\$Recycle.Bin" >nul 2>&1
echo  [OK] Limpeza concluida.
echo temporarios: ok >> "%LOG%"
exit /b

:limparpasta
if not exist "%~1" exit /b
del /f /s /q /a "%~1\*" >nul 2>&1
for /d %%D in ("%~1\*") do rd /s /q "%%D" >nul 2>&1
exit /b

:: ------------------------------------------------------------
:cleanmgr
echo.
echo  [*] Configurando e executando a Limpeza de Disco...
echo      (pode levar alguns minutos, uma janela vai abrir)
set "VC=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
for %%K in (
    "Active Setup Temp Folders"
    "Downloaded Program Files"
    "Internet Cache Files"
    "Memory Dump Files"
    "Old ChkDsk Files"
    "Previous Installations"
    "Recycle Bin"
    "Service Pack Cleanup"
    "Setup Log Files"
    "System error memory dump files"
    "System error minidump files"
    "Temporary Files"
    "Temporary Setup Files"
    "Thumbnail Cache"
    "Update Cleanup"
    "Upgrade Discarded Files"
    "Windows Error Reporting Archive Files"
    "Windows Error Reporting Queue Files"
    "Windows Error Reporting System Archive Files"
    "Windows Error Reporting System Queue Files"
    "Windows Upgrade Log Files"
) do (
    reg add "%VC%\%%~K" /v StateFlags0064 /t REG_DWORD /d 2 /f >nul 2>&1
)
start /wait cleanmgr /sagerun:64
echo  [OK] Limpeza de disco concluida.
echo cleanmgr: ok >> "%LOG%"
exit /b

:: ------------------------------------------------------------
:visual
echo.
echo  [*] Ajustando efeitos visuais para desempenho...
:: 2 = "Ajustar para obter um melhor desempenho"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul
:: Mantem as fontes suavizadas (texto fica legivel)
reg add "HKCU\Control Panel\Desktop" /v FontSmoothing /t REG_SZ /d 2 /f >nul
:: Menus abrem mais rapido
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 100 /f >nul
:: Desliga animacao de minimizar/maximizar
reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f >nul
:: Desliga a transparencia do Aero
reg add "HKCU\Software\Microsoft\Windows\DWM" /v ColorizationOpaqueBlend /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\Windows\DWM" /v EnableAeroPeek /t REG_DWORD /d 0 /f >nul
:: Programas travados fecham mais rapido ao desligar
reg add "HKCU\Control Panel\Desktop" /v WaitToKillAppTimeout /t REG_SZ /d 5000 /f >nul
reg add "HKCU\Control Panel\Desktop" /v HungAppTimeout /t REG_SZ /d 3000 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v WaitToKillServiceTimeout /t REG_SZ /d 5000 /f >nul
echo  [OK] Efeitos visuais ajustados (vale apos sair e entrar de novo).
echo visual: ok >> "%LOG%"
exit /b

:: ------------------------------------------------------------
:energia
echo.
echo  [*] Ativando plano "Alto desempenho"...
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
if errorlevel 1 (
    echo  [!] Plano nao encontrado, criando a partir do padrao...
    powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
)
echo  [OK] Plano de energia ativo:
powercfg -getactivescheme
echo      Em notebook isso gasta mais bateria; volte com a opcao 14.
echo energia: ok >> "%LOG%"
exit /b

:: ------------------------------------------------------------
:servicos
echo.
echo  [*] Desativando servicos que a maioria nao usa...
::  RemoteRegistry  - Registro remoto (tambem melhora seguranca)
::  Fax             - Fax
::  WMPNetworkSvc   - Compartilhamento de rede do Windows Media Player
::  TabletInputService - Painel de entrada de Tablet PC (nao desative em tela de toque)
::  WerSvc          - Relatorio de erros do Windows
::  DiagTrack       - Telemetria (existe apos algumas atualizacoes)
::  PcaSvc          - Assistente de compatibilidade de programas
for %%S in (RemoteRegistry Fax WMPNetworkSvc TabletInputService WerSvc DiagTrack PcaSvc) do (
    sc query %%S >nul 2>&1
    if not errorlevel 1 (
        sc stop %%S >nul 2>&1
        sc config %%S start= disabled >nul 2>&1
        echo      - %%S desativado
        echo servico desativado: %%S >> "%LOG%"
    )
)
echo.
set "busca="
set /p "busca=  Desativar tambem a Indexacao (Windows Search)? Deixa o PC mais leve, mas a busca do menu Iniciar fica lenta. (S/N): "
if /i "!busca!"=="S" (
    sc stop WSearch >nul 2>&1
    sc config WSearch start= disabled >nul 2>&1
    echo      - WSearch desativado
    echo servico desativado: WSearch >> "%LOG%"
)
echo  [OK] Servicos ajustados.
exit /b

:: ------------------------------------------------------------
:rede
echo.
echo  [*] Limpando cache de DNS...
ipconfig /flushdns >nul
echo  [*] Resetando Winsock e TCP/IP...
netsh winsock reset >nul
netsh int ip reset "%DIR%reset-ip.log" >nul
echo  [*] Ativando ajuste automatico de janela TCP...
netsh int tcp set global autotuninglevel=normal >nul
echo  [OK] Rede ajustada. Reinicie o computador.
echo rede: ok >> "%LOG%"
exit /b

:: ------------------------------------------------------------
:desfrag
echo.
echo  ATENCAO: so faca isto se o C: for HD comum. Em SSD desfragmentar
echo  so desgasta o disco sem ganho nenhum.
set "conf="
set /p "conf=  O disco C: e um HD (nao SSD)? (S/N): "
if /i not "!conf!"=="S" (
    echo  Cancelado.
    exit /b
)
echo  [*] Desfragmentando C: (pode levar mais de uma hora)...
defrag %SystemDrive% /U /V
echo desfrag: ok >> "%LOG%"
exit /b

:: ------------------------------------------------------------
:ssd
echo.
echo  [*] Desligando desfragmentacao agendada...
schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Disable >nul 2>&1
echo  [*] Desligando Superfetch e Prefetch (inuteis em SSD)...
sc stop SysMain >nul 2>&1
sc config SysMain start= disabled >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f >nul
echo  [*] Confirmando que o TRIM esta ativo...
fsutil behavior set DisableDeleteNotify 0 >nul
echo  [OK] Ajustes de SSD aplicados.
echo ssd: ok >> "%LOG%"
exit /b

:: ------------------------------------------------------------
:hibernacao
echo.
echo  [*] Desativando hibernacao (apaga o hiberfil.sys)...
powercfg -h off
echo  [OK] Hibernacao desativada. Para voltar: powercfg -h on
echo hibernacao: off >> "%LOG%"
exit /b

:: ------------------------------------------------------------
:sfc
echo.
echo  [*] Verificando arquivos do sistema (10 a 30 minutos)...
sfc /scannow
echo sfc: executado >> "%LOG%"
exit /b

:: ------------------------------------------------------------
:inicializacao
echo.
echo  Programas que iniciam com o Windows:
echo  ----------------------------------------------------------
wmic startup get Caption,Command /format:list | findstr /r /v "^$"
echo  ----------------------------------------------------------
echo  Para desligar algum, abrindo o msconfig na aba Inicializacao...
echo  (desmarque o que nao precisa: atualizadores, Java, Adobe etc.
echo   NAO desmarque o antivirus nem drivers de som/video)
start msconfig -4
exit /b

:: ------------------------------------------------------------
:desfazer
echo.
echo  [*] Voltando efeitos visuais ao padrao do Windows...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 400 /f >nul
reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 1 /f >nul
reg add "HKCU\Software\Microsoft\Windows\DWM" /v ColorizationOpaqueBlend /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\DWM" /v EnableAeroPeek /t REG_DWORD /d 1 /f >nul
echo  [*] Voltando ao plano de energia "Equilibrado"...
powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e >nul 2>&1
echo  [*] Reativando servicos...
for %%S in (RemoteRegistry Fax WMPNetworkSvc TabletInputService WerSvc DiagTrack PcaSvc) do (
    sc config %%S start= demand >nul 2>&1
)
sc config WSearch start= delayed-auto >nul 2>&1
sc start WSearch >nul 2>&1
sc config SysMain start= auto >nul 2>&1
sc start SysMain >nul 2>&1
sc config PcaSvc start= auto >nul 2>&1
sc start PcaSvc >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 3 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 3 /f >nul
schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Enable >nul 2>&1
echo  [OK] Ajustes desfeitos. Reinicie o computador.
echo  (Para desfazer TUDO de uma vez, use tambem a Restauracao do
echo   Sistema e escolha o ponto "Antes do Otimizador Win7".)
echo desfazer: ok >> "%LOG%"
exit /b

@echo off
setlocal
title Automatizacion de Interfaces Speedo - Connekta V2

:: 1. CONFIGURACION DE RUTAS Y TIEMPOS
set "RUTA_SPEEDO=C:\Program Files (x86)\Interfaces Y Soluciones\Connekta V2\Speedo"
:: 30 minutos = 1800 segundos
set /a TIEMPO_LIMITE=1800

:: Cambiar al directorio de trabajo (Crucial para que los sub-bats encuentren sus dependencias)
cd /d "%RUTA_SPEEDO%"

echo =====================================================
echo INICIANDO CADENA DE TAREAS SPEEDO - %date% %time%
echo =====================================================

:: --- TAREA 1: Importar Ordenes (Con límite de 30 minutos) ---
echo [%time%] Ejecutando ImportarOdenes.bat...

:: Lanzamos el proceso en segundo plano con una etiqueta de título para rastrearlo
start "PROCESO_IMPORTAR_ORDENES" /b cmd /c "ImportarOdenes.bat"

set /a CONTADOR=%TIEMPO_LIMITE%

:BUCLE_ESPERA
:: Comprobamos si el proceso sigue ejecutándose
tasklist /fi "WINDOWTITLE eq PROCESO_IMPORTAR_ORDENES*" 2>nul | find /i "cmd.exe" >nul
if %errorlevel% neq 0 (
    echo [%time%] ImportarOdenes finalizo correctamente.
    goto SIGUIENTE_TAREA
)

:: Esperar 1 segundo y restar al contador
timeout /t 1 /nobreak >nul
set /a CONTADOR-=1

if %CONTADOR% gtr 0 goto BUCLE_ESPERA

:: Si el contador llega a 0, se superó el tiempo límite
echo [ALERTA] ImportarOdenes excedio los 30 minutos. Forzando finalizacion...
taskkill /fi "WINDOWTITLE eq PROCESO_IMPORTAR_ORDENES*" /t /f >nul 2>&1

:SIGUIENTE_TAREA
echo -----------------------------------------------------

:: --- TAREA 2: Generar Guias ---
echo [%time%] Ejecutando GenerarGuias.bat...
call "GenerarGuias.bat"
if %errorlevel% neq 0 echo [ADVERTENCIA] GenerarGuias termino con error %errorlevel%
echo -----------------------------------------------------

:: --- TAREA 3: Cambio Estado Start Handling ---
echo [%time%] Ejecutando CambioEstadoStartHandling.bat...
call "CambioEstadoStartHandling.bat"
if %errorlevel% neq 0 echo [ADVERTENCIA] CambioEstadoStartHandling termino con error %errorlevel%
echo -----------------------------------------------------

:: --- TAREA 4: Cambio Estado Invoiced ---
echo [%time%] Ejecutando CambioEstadoInvoiced.bat...
call "CambioEstadoInvoiced.bat"
if %errorlevel% neq 0 echo [ADVERTENCIA] CambioEstadoInvoiced termino con error %errorlevel%

echo =====================================================
echo [%time%] PROCESO COMPLETO FINALIZADO
echo =====================================================
:: Mantiene la ventana abierta 10 segundos para revisión visual en ejecuciones manuales
timeout /t 10
exit
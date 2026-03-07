@echo off
setlocal

REM === EDIT THESE PATHS ===
set "OUT_DIR=.\out_publish"
set "PROJECT_OR_SOLUTION=.\CableGlandPlanner.csproj"

REM If obfuscar is NOT in PATH, set full path here:
REM set "OBFUSCAR_EXE=C:\Path\To\obfuscar.exe"
set "OBFUSCAR_EXE=obfuscar"

set "OBFUSCAR_XML=.\obfuscar.xml"

REM This is where Obfuscar writes the obfuscated DLL (edit if different):
set "OBF_OUT_DLL=.\bin\Release\net8.0-windows\obf_tmp\CableGlandPlanner.dll"

REM This is the DLL inside the publish folder (edit name if different):
set "PUBLISH_DLL=%OUT_DIR%\CableGlandPlanner.dll"

REM This is the final single-file EXE name inside publish (edit if different):
set "FINAL_EXE=%OUT_DIR%\CableGlandPlanner.exe"

REM Your signing script path:
set "SIGN_SCRIPT=C:\Temp\VS-Sign.ps1"
REM ========================


dotnet publish "%PROJECT_OR_SOLUTION%" -c Release -r win-x64 -p:PublishSingleFile=true -p:SelfContained=false -o "%OUT_DIR%"
if errorlevel 1 exit /b 1

"%OBFUSCAR_EXE%" "%OBFUSCAR_XML%"
if errorlevel 1 exit /b 1

copy /y "%OBF_OUT_DLL%" "%PUBLISH_DLL%"
if errorlevel 1 exit /b 1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SIGN_SCRIPT%" -target "%FINAL_EXE%"
if errorlevel 1 exit /b 1

echo DONE: %FINAL_EXE%
endlocal

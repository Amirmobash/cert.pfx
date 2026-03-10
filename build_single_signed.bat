## 📁 Repository Structure (Example)

```
YourRepo/
├── CableGlandPlanner.csproj
├── obfuscar.xml                 (Obfuscar configuration)
├── build-and-sign.bat            (master build script)
├── sign.ps1                      (PowerShell signing script – optional)
└── .github/workflows/build.yml   (GitHub Actions CI)
```

---

## 🔧 Prerequisites

- **.NET SDK** (version matching your project, e.g., 6.0, 8.0)
- **Obfuscar** – install as a .NET tool:  
  `dotnet tool install -g Obfuscar.GlobalTool`  
  or reference it locally via a package.
- **Windows SDK** (for `signtool.exe`) – included with Visual Studio or install separately.
- A code‑signing certificate (`.pfx` file).

---

## ⚠️ Important: The Correct Order of Operations

The original script attempted to obfuscate **after** publishing the single‑file EXE.  
This **does not work** because the single file is already packaged. The obfuscated DLL must be injected **before** the single‑file bundling.

**Correct workflow:**

1. **Build** the project normally (producing the DLL in `bin\Release\netX.Y\`).
2. **Run Obfuscar** on that DLL, generating an obfuscated DLL (in a temp folder).
3. **Copy** the obfuscated DLL back to the original build output location (overwriting the original).
4. **Publish** the project as a single file – the publish process will now pick up the obfuscated DLL.
5. **Sign** the final single‑file executable.

---

## 📜 The Master Batch Script (`build-and-sign.bat`)

Save this script in your project root. Edit the variables at the top to match your paths and settings.

```batch
@echo off
setlocal enabledelayedexpansion

REM ========== CONFIGURATION ==========
set "CONFIGURATION=Release"
set "RUNTIME=win-x64"
set "FRAMEWORK=net8.0-windows"           <-- change to your TFM
set "PROJECT=CableGlandPlanner.csproj"
set "SOLUTION_DIR=%~dp0"
set "OUT_DIR=%SOLUTION_DIR%out_publish"

set "OBFUSCAR_EXE=obfuscar"               <-- or full path
set "OBFUSCAR_XML=%SOLUTION_DIR%obfuscar.xml"

REM The DLL after normal build (before obfuscation)
set "ORIGINAL_DLL=%SOLUTION_DIR%bin\%CONFIGURATION%\%FRAMEWORK%\%PROJECT_NAME%.dll"

REM Where Obfuscar writes the obfuscated DLL (must match <OutputDir> in obfuscar.xml)
set "OBF_OUT_DIR=%SOLUTION_DIR%bin\%CONFIGURATION%\%FRAMEWORK%\obfuscated"
set "OBF_DLL=%OBF_OUT_DIR%\%PROJECT_NAME%.dll"

REM Path to signing script or signtool command
set "SIGNTOOL=C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe"
set "PFX_PATH=C:\path\to\your\certificate.pfx"
set "PFX_PASSWORD="                       <-- leave empty if no password
set "TIMESTAMP=http://timestamp.digicert.com"

REM Final single-file EXE after publish
set "FINAL_EXE=%OUT_DIR%\%PROJECT_NAME%.exe"
REM ====================================

echo ===== Step 1: Clean old output =====
if exist "%OUT_DIR%" rmdir /s /q "%OUT_DIR%"
if exist "%OBF_OUT_DIR%" rmdir /s /q "%OBF_OUT_DIR%"

echo ===== Step 2: Build the project (normal) =====
dotnet build "%PROJECT%" -c %CONFIGURATION% --no-incremental
if errorlevel 1 exit /b 1

echo ===== Step 3: Run Obfuscar =====
"%OBFUSCAR_EXE%" "%OBFUSCAR_XML%"
if errorlevel 1 exit /b 1

echo ===== Step 4: Replace original DLL with obfuscated version =====
copy /y "%OBF_DLL%" "%ORIGINAL_DLL%"
if errorlevel 1 exit /b 1

echo ===== Step 5: Publish single-file EXE =====
dotnet publish "%PROJECT%" -c %CONFIGURATION% -r %RUNTIME% ^
  -p:PublishSingleFile=true ^
  -p:SelfContained=false ^
  -p:DebugType=None -p:DebugSymbols=false ^
  -o "%OUT_DIR%"
if errorlevel 1 exit /b 1

echo ===== Step 6: Sign the final EXE =====
if not exist "%FINAL_EXE%" (
  echo ERROR: Final EXE not found at "%FINAL_EXE%"
  exit /b 1
)

if "%PFX_PASSWORD%"=="" (
  "%SIGNTOOL%" sign /f "%PFX_PATH%" /fd SHA256 /tr "%TIMESTAMP%" /td SHA256 "%FINAL_EXE%"
) else (
  "%SIGNTOOL%" sign /f "%PFX_PATH%" /p "%PFX_PASSWORD%" /fd SHA256 /tr "%TIMESTAMP%" /td SHA256 "%FINAL_EXE%"
)
if errorlevel 1 exit /b 1

echo ===== Step 7: Verify signature =====
"%SIGNTOOL%" verify /pa /v "%FINAL_EXE%"
if errorlevel 1 exit /b 1

echo ===== SUCCESS =====
echo Signed single-file EXE: %FINAL_EXE%
endlocal
```

---

## 🛡️ Obfuscar Configuration (`obfuscar.xml`)

Create this file in your project root. Adjust paths and options as needed.

```xml
<?xml version='1.0'?>
<Obfuscator>
  <Var name="InPath" value="bin\Release\net8.0-windows" />
  <Var name="OutPath" value="bin\Release\net8.0-windows\obfuscated" />

  <Module file="$(InPath)\CableGlandPlanner.dll" />

  <!-- Optional: keep some names public if required by reflection etc. -->
  <!--
  <SkipType name="MyNamespace.PublicClass" />
  <SkipMethod name="MyNamespace.MyClass::MyMethod" />
  -->

  <Property name="MarkedOnly" value="false" />   <!-- obfuscate everything -->
  <Property name="RenameProperties" value="true" />
  <Property name="KeepPublicApi" value="false" />  <!-- set true if you need public API unchanged -->
</Obfuscator>
```

**Note:** The `<Var name="OutPath">` must match the `%OBF_OUT_DIR%` in the batch script.

---

## ✍️ Signing via PowerShell (Alternative)

If you prefer a PowerShell script for signing (e.g., to handle passwords securely via environment variables), create `sign.ps1`:

```powershell
param(
    [string]$target,
    [string]$pfxPath,
    [string]$pfxPass,
    [string]$timestamp = "http://timestamp.digicert.com"
)

if (-not (Test-Path $target)) {
    Write-Error "Target file not found: $target"
    exit 1
}

$signtool = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe"
if (-not (Test-Path $signtool)) {
    Write-Error "SignTool not found at $signtool"
    exit 1
}

if ($pfxPass) {
    & $signtool sign /f $pfxPath /p $pfxPass /fd SHA256 /tr $timestamp /td SHA256 $target
} else {
    & $signtool sign /f $pfxPath /fd SHA256 /tr $timestamp /td SHA256 $target
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Signing failed"
    exit $LASTEXITCODE
}

& $signtool verify /pa /v $target
exit $LASTEXITCODE
```

Then modify the batch script to call:

```batch
powershell -NoProfile -ExecutionPolicy Bypass -File sign.ps1 -target "%FINAL_EXE%" -pfxPath "%PFX_PATH%" -pfxPass "%PFX_PASSWORD%"
```

---

## 🤖 GitHub Actions Integration

Create `.github/workflows/build.yml` for automated builds on push or release.

```yaml
name: Build and Sign

on:
  push:
    tags:
      - 'v*'               # run on version tags
  workflow_dispatch:        # allow manual trigger

jobs:
  build:
    runs-on: windows-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: 8.0.x

      - name: Install Obfuscar tool
        run: dotnet tool install -g Obfuscar.GlobalTool

      - name: Run build script
        run: .\build-and-sign.bat
        env:
          PFX_PASSWORD: ${{ secrets.PFX_PASSWORD }}   # if your cert needs a password

      - name: Upload signed EXE as artifact
        uses: actions/upload-artifact@v4
        with:
          name: CableGlandPlanner-signed
          path: out_publish\CableGlandPlanner.exe
```

**Important:** Store your code‑signing certificate (`.pfx`) as a GitHub secret (base64 encoded) and decode it during the workflow. You’ll need additional steps to write the PFX file from the secret.

---

## 🧪 Testing Locally

1. Install Obfuscar globally:  
   `dotnet tool install -g Obfuscar.GlobalTool`
2. Edit the batch script with your correct paths and certificate.
3. Run `build-and-sign.bat` from a **Developer Command Prompt for VS** (to have `signtool` in PATH, or provide full path).
4. The final signed EXE will be in `out_publish\`.

---

## ❓ FAQ / Troubleshooting

**Q: Why obfuscate before publish?**  
A: The single‑file packager embeds the IL of your DLLs. Obfuscating the DLL before packaging ensures the embedded code is obfuscated.

**Q: Can I use self‑contained (`SelfContained=true`) instead of framework‑dependent?**  
A: Yes, change the `-p:SelfContained=false` to `true`. The script works for both.

**Q: My Obfuscar output path is different – how to adjust?**  
A: Edit `OBF_OUT_DIR` in the script to match the `<OutputDir>` in your `obfuscar.xml`.

**Q: How do I handle certificate passwords securely in CI?**  
A: Use GitHub Secrets. In the workflow, set an environment variable `PFX_PASSWORD` from `secrets.PFX_PASSWORD` and use it in the script.

**Q: SignTool fails with “The specified PFX password is not correct.”**  
A: Ensure the password variable is correctly passed. If your PFX has no password, leave `PFX_PASSWORD` empty in the script and the signing command will omit the `/p` parameter.

---

## 🎯 Summary

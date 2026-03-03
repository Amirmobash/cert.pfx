# Code Signing (Official) — Single-File EXE (Windows)

This section explains **only the signing process** for a **final single-file `.exe`** so Windows/SmartScreen is less likely to warn.

> The signature is stored **inside the EXE**. You don’t place a separate “signature file” next to it.

---

## Prerequisites
- A **code signing certificate** as a `.pfx` file  
  Example: `C:\path\cert.pfx` (no password)
- Your **final EXE** (the one you deliver to users)  
  Example:  
  `C:\Users\ladan\source\repos\CableGlandPlanner_WinForms_DE\CableGlandPlanner\Output\CableGlandPlanner.exe`
- `signtool.exe` (comes with **Windows SDK**)

---

## 1) Check `signtool` is available
Open **Command Prompt (CMD)** and run:

```bat
where signtool
````

If nothing is returned, install **Windows 10/11 SDK** (Signing Tools).

---

## 2) Sign the final EXE (PFX without password)

In **CMD**:

```bat
set PFX=C:\path\cert.pfx
set EXE=C:\Users\ladan\source\repos\CableGlandPlanner_WinForms_DE\CableGlandPlanner\Output\CableGlandPlanner.exe

signtool sign /f "%PFX%" /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 "%EXE%"
```

If `signtool` still asks for a password (even though your PFX has none), try:

```bat
signtool sign /f "%PFX%" /p "" /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 "%EXE%"
```

---

## 3) Verify the signature

```bat
signtool verify /pa /v "%EXE%"
```

You should see: **Successfully verified**

---

## Important Notes

* **Sign after publishing/building.** If you rebuild/publish again, the EXE changes and must be signed again.
* **Timestamping** (`/tr ... /td SHA256`) is recommended so the signature remains valid after certificate expiration.
* Even with a valid signature, **SmartScreen reputation** may take time to build for a new publisher/app.

---

```
```

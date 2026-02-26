# AGENTS.md

## Repository overview

MEM.Zone is a collection of standalone scripts, reports, tools, and documentation for Microsoft Endpoint Management (MEM). There is **no buildable application, no package manager, no CI/CD, and no test framework**. The repository contains:

- **PowerShell** scripts (~131 `.ps1` files) in `Scripts/PowerShell/`
- **SQL / T-SQL** scripts (~68 `.sql` files) in `Scripts/SQL/` and `Reports/`
- **Bash** scripts (~10 `.sh` files) in `Scripts/Bash/`
- **Kusto / KQL** queries in `Scripts/Kusto/`
- SSRS report definitions (`.rdl`), ADMX policy templates, and documentation

## Cursor Cloud specific instructions

### Tools available

| Tool | Purpose | Command |
|---|---|---|
| PowerShell Core 7.5+ (`pwsh`) | Run and lint `.ps1` scripts | `pwsh -Command "..."` |
| PSScriptAnalyzer 1.24+ | Lint PowerShell scripts | `pwsh -Command "Invoke-ScriptAnalyzer -Path <path> -Recurse"` |
| ShellCheck 0.9+ | Lint `.sh` scripts | `shellcheck <path>` |

### Linting

- **PowerShell:** `pwsh -Command "Invoke-ScriptAnalyzer -Path './Scripts/PowerShell/' -Recurse -Severity Error,Warning"`
- **Bash:** `shellcheck <file.sh>` (run against individual files or all via `find . -name '*.sh' -exec shellcheck {} +`)
- **SQL:** No linter is configured; review SQL scripts manually.

### Running scripts

Most PowerShell scripts target Windows + SCCM/Intune/AD and cannot run end-to-end on Linux. However, standalone functions (e.g. `Scripts/PowerShell/_Functions/Format-Bytes/Format-Bytes.ps1`) can be dot-sourced and tested:

```powershell
pwsh -Command ". './Scripts/PowerShell/_Functions/Format-Bytes/Format-Bytes.ps1'; Format-Bytes -Bytes 1073741824"
```

### Key caveats

- There is no build step, no `package.json`, no `requirements.txt`, and no dependency manifest.
- The update script only needs to ensure `pwsh`, `PSScriptAnalyzer`, and `shellcheck` are present.
- Many scripts depend on Windows-only modules (ConfigurationManager, ActiveDirectory, etc.) and cannot execute on Linux beyond syntax/lint checks.

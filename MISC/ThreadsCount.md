# Thread Count - ThreadsCount.ps1

This script lists the running instances of a named process along with their thread objects.

## How it works

1. `Get-Process -Name "servicenavn"` gets all processes matching the given name (replace `"servicenavn"` with the actual process name).
2. `| Select-Object Name, Id, Threads` outputs each process's name, PID, and its `Threads` collection.

## Usage

Edit the process name before running:

```powershell
Get-Process -Name "servicenavn" | Select-Object Name, Id, Threads
```

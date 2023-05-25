# WinZip Decompression of a Single File with PowerShell

This PowerShell script performs decompression on a single `.zipx` file using WinZip. The file path to WinZip's executable, the file to be decompressed, and the password for the file are specified. After the decompression operation, the script performs a "ping" command to cause a delay, which could be used to prevent overloading the system resources or to provide a pause before executing additional operations.

The script works with the following commands:
* `Start-Process`: Starts a WinZip process for file decompression.
* `ping localhost -n 120`: Adds a delay after the decompression process.

## Code

```powershell
Start-Process -FilePath "C:\Program Files\WinZip\WZUNZIP.EXE" -ArgumentList "-e -d -sPASS ""n:\Daily\file.zipx"" c:\"
ping localhost -n 120


Notes:
- The `-e` flag extracts files.
- The `-d` flag restores the directory structure.
- The `-sPASS` flag specifies the password for the compressed files. Please replace `PASS` with your actual password.
- The `"n:\Daily\file.zipx"` is the path of the `.zipx` file to be decompressed.
- The `c:\` at the end is the destination directory where the files will be decompressed to.

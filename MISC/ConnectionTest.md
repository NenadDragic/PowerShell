# Connection Test - ConnectionTest.ps1

This script tests connectivity to a given IP address on port 22 (SSH) using three different methods: `Test-NetConnection`, Telnet, and a verbose SSH handshake.

## How it works

1. Prompts for an IP address (`Read-Host`) and hardcodes the target port to 22.
2. Runs `Test-NetConnection -ComputerName $IP -Port $Port -InformationLevel Detailed` and prints the full result.
3. Runs `telnet` against the IP/port via `cmd /c`, printing the output (or a note that no output doesn't necessarily mean failure).
4. Runs `ssh -v` with a 5-second connect timeout, disabled host-key checking, and batch mode (no password prompt), printing the verbose handshake output line by line.

## Usage

```powershell
.\ConnectionTest.ps1
```

You'll be prompted to enter the target IP address. Press Ctrl+C (or Ctrl+]) if the SSH step hangs.

```powershell
# ConnectionTest.ps1
# Tester SSH-forbindelse til en given IP via Test-NetConnection, Telnet og SSH

$IP = Read-Host "Indtast IP-adresse"
$Port = 22

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Test-NetConnection mod $IP port $Port" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$tcpTest = Test-NetConnection -ComputerName $IP -Port $Port -InformationLevel Detailed
$tcpTest | Format-List

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Telnet mod $IP port $Port" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$telnetResult = & cmd /c "echo. | telnet $IP $Port 2>&1"
if ($telnetResult) {
    Write-Host $telnetResult
} else {
    Write-Host "Telnet returnerede intet output (forbindelsen kan stadig have lykkedes)"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " SSH verbose mod $IP" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "(Afbryd med Ctrl+C eller CTRL+] hvis den hænger)" -ForegroundColor Yellow

$sshOutput = & ssh -v -o "ConnectTimeout=5" -o "StrictHostKeyChecking=no" -o "BatchMode=yes" $IP 2>&1
$sshOutput | ForEach-Object { Write-Host $_ }

Write-Host "`n========================================" -ForegroundColor Green
Write-Host " Test afsluttet" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green
```

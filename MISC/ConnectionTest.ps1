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

$nl = [Environment]::NewLine
[dateTime]$time = (get-date).addDays(-1)
$log = Get-EventLog -LogName System -After $time -Source 'Server Administrator' -EntryType Error,Warning -EA 0
IF (!$log){
    Write-Host 'Pass'
}
ELSE{
    Write-Host '======================================================' $nl
    Write-Host '======================================================' $nl
    Write-Host 'Machine Name:' $env:computername $nl
    Write-Host 'Description: Labtech detected Dell OpenManage system log failure events. See all Dell OpenManage error/warnings for the past 14 days below...' $nl
    Write-Host '======================================================' $nl
    [dateTime]$time = (get-date).addDays(-14)
    Get-EventLog -LogName System -After $time -Source 'Server Administrator' -EntryType Error,Warning -EA 0 | Format-List TimeGenerated, Message
    Write-Host '======================================================' $nl
    Write-Host '======================================================'
}

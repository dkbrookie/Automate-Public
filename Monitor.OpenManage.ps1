[dateTime]$time = (get-date).addDays(-1)
$log = Get-EventLog -LogName System -After $time -Source 'Server Administrator' -EntryType Error,Warning -EA 0
If (!$log){
    Write-Output '!SUCCESS: No failures found'
}
Else {
    Write-Output "!FAILED: Machine Name: $env:computername"
    Write-Output 'Description: Automate detected Dell OpenManage system log failure events. See all Dell OpenManage error/warnings for the past 14 days below...'
    [dateTime]$time = (get-date).addDays(-14)
    Get-EventLog -LogName System -After $time -Source 'Server Administrator' -EntryType Error,Warning -EA 0 | Format-List TimeGenerated, Message
}

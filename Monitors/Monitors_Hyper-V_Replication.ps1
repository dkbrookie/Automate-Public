## Possible outputs from MS: NotApplicable, Normal, Warning, Critical

Try {
    $health = (Get-VMReplication).Health
    $machine = $env:COMPUTERNAME
    If ($health -eq 'Normal') {
        Write-Output "!SUCCESS: Replication status is Normal on $machine"
    } ElseIf ($health -eq 'Warning') {
        Write-Output "!ERROR: Replication is in a warning state on $machine! Please address the issue immediately!"
    } ElseIf ($health -eq 'Critical') {
        Write-Output "!ERROR: Repliation status is critical on $machine! Please address the issue immidiately!"
    } ElseIf ($health -eq 'NotApplicable') {
        Write-Output "!SUCCESS: Replication check not applicable to $machine"
    } Else {
        Write-Output "Unknown output"
    }
} Catch {
    Write-Output "$_"
}
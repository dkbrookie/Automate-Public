Function Get-Tree($Path,$Include='*'){
    @(Get-Item $Path -Include $Include -Force) +
        (Get-ChildItem $Path -Recurse -Include $Include -Force) | Sort PSPath -Descending -Unique
}

Function Remove-Tree($Path,$Include='*'){
    Get-Tree $Path $Include | Remove-Item -Force -Recurse
}

##Set the udpate path to 'Semi Annual Channel'
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name BranchReadinessLevel -Value 32
##Set major OS revision forced updates to defer 365 days
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name DeferFeatureUpdatesPeriodInDays -Value 365

$path1 = "C:\Windows\UpdateAssistant"
$path2 = "C:\Windows\UpdateAssistantV2"

##If the UpdateAssistant dir exists, delete it and everything in it
If(Test-Path $path1){
    Write-Output "!DEL: Deleted $path1"
    cmd.exe /c "echo y| takeown /F $path1\* /R /A" | Out-Null
    cmd.exe /c "echo y| cacls $path1\*.* /T /grant administrators:F" | Out-Null
    Remove-Tree $path1
}
Else{
    Write-Output "$path1 does not exist"
}

##If the UpdateAssistantV2 dir exists, delete it and everything in it
If(Test-Path $path2){
    Write-Output "!DEL: Deleted $path2"
    cmd.exe /c "echo y| takeown /F $path2\* /R /A" | Out-Null
    cmd.exe /c "echo y| cacls $path2\*.* /T /grant administrators:F" | Out-Null
    Remove-Tree $path2
}
Else{
    Write-Output "$path2 does not exist"
}

##Delete all scheduled tasks UpgradeAssistant created
$tasks = Get-ScheduledTask | Where {$_.TaskName -like "UpdateAssistant*"} | Select -ExpandProperty TaskName
If($tasks){
    ForEach($task in $tasks){
        Write-Output "!DEL: Task $task has been deleted"
        Unregister-ScheduledTask -TaskName $task -Confirm:$False
    }
}
Else{
    Write-Output "No scheduled tasks found for UpdateAssistant"
}

#Disable Automatic App Update scheduled task (can be used to push out prompts for feature updates)
$result = Get-ScheduledTask | Where {$_.TaskName -eq "Automatic App Update"}
If($result){
        Write-Output "!DEL: Task Automatic App Update has been disabled"
        Disable-ScheduledTask -TaskName $result
    }
Else{
    Write-Output "No scheduled tasks found for Automatic App Update"
}

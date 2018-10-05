Function Get-Tree($Path,$Include='*'){
    @(Get-Item $Path -Include $Include -Force) +
        (Get-ChildItem $Path -Recurse -Include $Include -Force) | Sort PSPath -Descending -Unique
}

Function Remove-Tree($Path,$Include='*'){
    Get-Tree $Path $Include | Remove-Item -Force -Recurse
}

$path1 = "C:\Windows\UpdateAssistant"
$path2 = "C:\Windows\UpdateAssistantV2"

If(Test-Path $path1){
    Write-Output "Deleted $path1"
    Remove-Tree $path1
}
Else{
    Write-Output "$path1 does not exist"
}

If(Test-Path $path2){
    Write-Output "Deleted $path2"
    Remove-Tree $path2
}
Else{
    Write-Output "$path2 does not exist"
}

$tasks = Get-ScheduledTask | Where {$_.TaskName -like "UpdateAssistant*"} | Select -ExpandProperty TaskName
If($tasks){
    ForEach($task in $tasks){
        Write-Output "Task $task has been deleted"
        Unregister-ScheduledTask -TaskName $task -Confirm:$False
    }
}
Else{
    Write-Output "No scheduled tasks found for UpdateAssistant"
}
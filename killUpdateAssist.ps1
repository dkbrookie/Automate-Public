Function Get-Tree($Path,$Include='*'){
    @(Get-Item $Path -Include $Include -Force) +
        (Get-ChildItem $Path -Recurse -Include $Include -Force) | Sort PSPath -Descending -Unique
}

Function Remove-Tree($Path,$Include='*'){
    Get-Tree $Path $Include | Remove-Item -Force -Recurse
}

$path1 = "C:\Windows\UpdateAssistant"
$path2 = "C:\Windows\UpdateAssistantV2"

Stop-Process -Name Windows10Upgrade -Force

If(Test-Path $path1){
    Write-Output "!DEL: Deleted $path1"
    cmd.exe /c "takeown /F $path1\* /R /A" | Out-Null
    cmd.exe /c "cacls $path1\*.* /T /grant administrators:F" | Out-Null
    Remove-Tree $path1
}
Else{
    Write-Output "$path1 does not exist"
}

If(Test-Path $path2){
    Write-Output "!DEL: Deleted $path2"
    cmd.exe /c "takeown /F $path2\* /R /A" | Out-Null
    cmd.exe /c "cacls $path2\*.* /T /grant administrators:F" | Out-Null
    Remove-Tree $path2
}
Else{
    Write-Output "$path2 does not exist"
}

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




Warning Result:Remove-Item : Cannot remove item
C:\Windows\UpdateAssistantV2\Windows10Upgrade.exe: Access to the path is
denied.
At line:7 char:31
      Get-Tree $Path $Include | Remove-Item -Force -Recurse
                                ~~~~~~~~~~~~~~~~~~~~~~~~~~~
      CategoryInfo          : InvalidArgument: (C:\Windows\Upda...ws10Upgrade.
   exe:FileInfo) [Remove-Item], ArgumentException
      FullyQualifiedErrorId : RemoveFileSystemItemArgumentError,Microsoft.Powe
   rShell.Commands.RemoveItemCommand
Remove-Item : Cannot remove item
C:\Windows\UpdateAssistantV2\Windows10Upgrade.exe: Access to the path is
denied.
At line:7 char:31
      Get-Tree $Path $Include | Remove-Item -Force -Recurse
                                ~~~~~~~~~~~~~~~~~~~~~~~~~~~
      CategoryInfo          : InvalidArgument: (Windows10Upgrade.exe:FileInfo)
    [Remove-Item], ArgumentException
      FullyQualifiedErrorId : RemoveFileSystemItemArgumentError,Microsoft.Powe
   rShell.Commands.RemoveItemCommand
Remove-Item : Cannot remove item C:\Windows\UpdateAssistantV2: The directory
is not empty.
At line:7 char:31
      Get-Tree $Path $Include | Remove-Item -Force -Recurse
                                ~~~~~~~~~~~~~~~~~~~~~~~~~~~
      CategoryInfo          : WriteError: (C:\Windows\UpdateAssistantV2:Direct
   oryInfo) [Remove-Item], IOException
      FullyQualifiedErrorId : RemoveFileSystemItemIOError,Microsoft.PowerShell
   .Commands.RemoveItemCommand
C:\Windows\UpdateAssistant does not exist
!DEL: Deleted C:\Windows\UpdateAssistantV2
No scheduled tasks found for UpdateAssistant

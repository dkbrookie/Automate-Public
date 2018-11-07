Function Get-Tree($Path,$Include='*'){
    @(Get-Item $Path -Include $Include -Force) +
        (Get-ChildItem $Path -Recurse -Include $Include -Force) | Sort PSPath -Descending -Unique
}

Function Remove-Tree($Path,$Include='*'){
    Get-Tree $Path $Include | Remove-Item -Force -Recurse
}

## Uninstall Desk Director
$portalName = "DKB Launch Pad"

$ProfileList = ('hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' | gci -EA 0 | Get-ItemProperty -EA 0)
$Paths = ($ProfileList | ?{$_.PSChildName.Length -gt 10} | %{$_.ProfileImagePath})
$Executables = @()
$Paths | %{
  $Path = $_
  $LocalAppData = $Path + "\AppData\Local\deskdirectorportal"
  $RoamingAppData = $Path + "\AppData\Roaming\$portalName"
  If((Test-Path $LocalAppData) -and (Test-Path $RoamingAppData)) {
    $Executables += dir $LocalAppData | ?{$_.PSIsContainer -and $_.name -like 'app-*'} | %{ dir $_.FullName *.exe }
  }
  $ExecutableNames = $Executables | Group Name | %{$_.Name}
  $ExecutableNames | %{
    taskkill /IM $_ /F 2>&1 | Out-Null
  }
  $updateExe = $LocalAppData + "\Update.exe"
  $uninstallParams = "--uninstall -s".Split("")
  If(Test-Path $updateExe) {
    &"$updateExe" $uninstallParams | echo "Waiting"
  }
  <#If($LocalAppData) {
    cmd.exe /c "takeown /F $LocalAppData\* /R /A" | Out-Null
    cmd.exe /c "cacls $LocalAppData\*.* /T /grant administrators:F" | Out-Null
    Remove-Tree $LocalAppdata -EA 0
  }
  If($RoamingAppData) {
    cmd.exe /c "takeown /F $RoamingAppData\* /R /A" | Out-Null
    cmd.exe /c "cacls $RoamingAppData\*.* /T /grant administrators:F" | Out-Null
    Remove-Tree $RoamingAppData -EA 0
  }#>
}

$ProgramsToUninstall = 'hklm:/Software/Microsoft/Windows/CurrentVersion/Uninstall','hklm:/Software/WOW6432Node/Microsoft/Windows/CurrentVersion/Uninstall' | gci -EA 0 | Get-ItemProperty -EA 0 | ?{$_.DisplayName -like "$portalName*Machine*"}
$ProgramsToUninstall | %{
  $Program = $_
  $UninstallString = $Program.UninstallString.Replace("/I","/X") + " /qn"
  iex "cmd /c '$UninstallString'"
}

## Remove from add/remove programs
New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS
$userList = Get-ChildItem "HKU:\*"
foreach($user in $userList) {
  $exists = Test-Path "HKU:\$user\Software\Microsoft\Windows\CurrentVersion\Uninstall\deskdirectorportal"
  If($exists -eq $True) {
    Remove-Item "HKU:\$user\Software\Microsoft\Windows\CurrentVersion\Uninstall\deskdirectorportal" -Confirm:$False -Force
  }
}

## Delete the shortcut on the users desktop and the main application dir in the user dir
$userPaths = Get-ChildItem "$env:SystemDrive\Users"
ForEach($user in $userPaths.Name) {
  Write-Output "Processing $user"
  Remove-Item "$env:SystemDrive\Users\$user\Desktop\'$portalName'.lnk" -EA 0
  $userLocal = "$env:SystemDrive\Users\$user\AppData\Local\deskdirectorportal"
  If((Test-Path $userLocal)) {
    cmd.exe /c "takeown /F "$userLocal"\* /R /A" | Out-Null
    cmd.exe /c "cacls "$userLocal"\*.* /T /grant administrators:F" | Out-Null
    Remove-Tree $userLocal -EA 0
  }
  $userRoaming = "$env:SystemDrive\Users\$user\AppData\Roaming\'$portalName'"
  If((Test-Path $userRoaming)) {
    cmd.exe /c "takeown /F "$userRoaming"\* /R /A" | Out-Null
    cmd.exe /c "cacls "$userRoaming"\*.* /T /grant administrators:F" | Out-Null
    Remove-Tree $userRoaming -EA 0
  }
}

## Delete the all users DKB Launch Pad shortcut
Remove-Item "$env:SystemDrive\Users\Public\Desktop\$portalName.lnk" -EA 0

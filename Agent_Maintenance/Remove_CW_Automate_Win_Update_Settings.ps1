function Invoke-Output {
    param ([string[]]$output)
    Write-Output ($output -join "`n`n")
}


# Set vars
$output = @()
$pathsToRemove = $('HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate','HKLM:\Software\Policies\Microsoft\Windows\DeliveryOptimization')
$hideWindowsUpdate = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'


# Stop WIndows update service so we can remove associated registry keys
$output += Stop-Service -Name wuauserv


# Remove these keys from registry that apply policy to Windows update. These Policy keys 
# are "GPO" settings so once nuked gives you control of Windows update again on the local 
# machine and takes away the banner for [Some setting managed by your organization]
foreach ($path in $pathsToRemove) {
    if ((Test-Path -Path $path -PathType Container -EA 0))  {
        $output += "Confirmed [$path] exists, removing registry key..."
        try {
            Remove-Item $path -Recurse -EA 0
        } catch {
            $output += "Failed to remove [$path]."
        }
        $output += "Successfully removed [$path]"
    } else {
        $output += "[$path] did not exist, good to go."
    }
}


# Remove the hide Windows Update reg setting
if ((Get-ItemProperty -Path $hideWindowsUpdate -Name 'SettingsPageVisibility' -EA 0).SettingsPageVisibility -like '*hide:windowsupdate*') {
    $output += "Confirmed hide Windows update reg settings exist, removing registry key..."
    try {
        Remove-ItemProperty -Path $hideWindowsUpdate -Name 'SettingsPageVisibility' -EA 0
    } catch {
        $output += "Failed to remove the hide windows update setting located at [$hideWindowsUpdate]"
    }
} else {
    $output += "Windows updates are not set to hide in registry!"
}


# Start Windows update service
$output += Start-Service -Name wuauserv


$output += "Full error output for troubleshooting-- note paths missing or a value missing is an OK error since that means there was nothing to remove"
$output += $Error


# Send final return
return Invoke-Output $output

Function Agent-Checkup {
    <#
    .SYNOPSIS
    Powershell module for Automate Agent health status/remediation
    
    .DESCRIPTION
    This is used to check the current overall health of the Automate agent against parameters defined.
    If any items are out of alignmenet compared to the defined best practice values, this function 
    attempts to remediate those issues.

    Logs for actions taken by this scripts are saved to "$env:ProgramFiles\DKB\DKBLogs".

    .PARAMETER AutomateServerURL
    The full FQDN including https:// to your automate server in singles quotes. Example: 'https://automate.yourdomain.com'.
    This parameter is required.

    .PARAMETER LocationID
    The Locaiton ID you want the agent to install to. By default this is 1. This parameter is not required.
    
    .PARAMETER InstallerToken
    Permits use of installer tokens for customized MSI downloads. (Other installer types are not supported). This parameter
    is required.

    .PARAMETER MSPName
    Enter the name of your MSP to be used in the fodler path created in sysdrive\Program Files\MSPName\

    .EXAMPLE
    Agent-Checkup -AutomateServerURL 'https://automate.yourdomain.com' -LocationID 541 -InstallerToken 'c245ecaw25asdasaaaqe222232aaa'
    
    .NOTES
    Version:        1.2.0
    Author:         Matthew Weir
    Website:        dkbinnovative.com
    Creation Date:  4/17/2019
    Purpose/Change: Automated agent health checkup/deployment

    Update Date: 1/19/2021
    Purpose/Change: Added additional logging, and added additional checks before attempting a reinstall. Also general script format cleanup.

    Update Date: 1/13/2021
    Purpose/Change: Added last server last check-in health check

    Update Date: 5/10/2020
    Purpose/Change: Adjusted server URL to be a parameter vs static value
    #>


    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$AutomateServerURL,
        [string]$LocationID = 1,
        [Parameter(Mandatory=$true)]
        [string]$InstallerToken,
        $MSPName = 'Connectwise Automate'
    )


    ## Single session changes only below
    ## Enable TLS, TLS1.1, TLS1.2, TLS1.3 in this session if they are available
    IF([Net.SecurityProtocolType]::Tls) {[Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls}
    IF([Net.SecurityProtocolType]::Tls11) {[Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11}
    IF([Net.SecurityProtocolType]::Tls12) {[Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12}
    IF([Net.SecurityProtocolType]::Tls13) {[Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13}


    ## Import Automate module
    Invoke-Expression (New-Object Net.WebClient).DownloadString('https://bit.ly/LTPoSh')


    ## Log start time
    $curDate = Get-Date
    $logOutput += ":::Script started $curDate:::"


    ## Set log dir
    $logDir = "$env:ProgramFiles\$MSPName\AutomateAgentRepairLogs"
    $installDateFile = "$logDir\LastInstallDate.txt"
    $installCountFile = "$logDir\InstallCount.txt"
    $agentHealthFile = "$logDir\AgentHealthLog.txt"
    ## Create log dir if it doesn't exist
    If (!(Test-Path -Path $logDir -PathType Container)) {
        New-Item -Path $logDir -ItemType Directory | Out-Null
    }


    ## Get current Automate Server URL from reg
    $currentAutomateServer = (Get-ItemProperty -Path 'HKLM:\Software\Labtech\Service' -Name 'Server Address' -EA 0).'Server Address'
    ## Check to see if Automate is currently installed
    If ((Get-Service -Name LTService -EA 0)) {
        ## Check the installed Automate server URL vs the desired $AutomateServerURL
        If ($currentAutomateServer -notlike "*$AutomateServerURL*") {
            ## Automate Server URL was not the $MSPName URL-- reinstall w/ $AutomateServerURL
            [array]$logOutput += "Found the current Automate Server URL is $currentAutomateServer but should be $AutomateServerURL. Reinstalling with correct URL..."
            [array]$logOutput += Reinstall-LTService -Server $AutomateServerURL -LocationID $LocationID -InstallerToken $InstallerToken -Force
            Set-Content -Path $installDateFile -Value $curDate
            If (!(Test-Path -Path $installCountFile -PathType Leaf)) {
                Set-Content -Path $installCountFile -Value 1
            } Else {
                $installCount = Get-Content -Path $installCountFile
                $installCount++
                Set-Content -Path $installCountFile -Value $installCount
            }
            ## Now that the agent has been reinstalled with the proper agent, exit the script. The script will re-run on a scheduled task
            ## so if there's other issues with the agent we'll know at next run.
            Break
        } Else {
            ## Automate Server URL looks good
            [array]$logOutput += "Confirmed the $MSPName Automate Agent is installed and the Automate Server URL is $AutomateServerURL"
        }


        ## Verify Automate services are running
        [array]$services = 'LTService','LTSvcMon'
        ForEach ($service in $services) {
            If ((Get-Service -Name $service).Status -ne 'Running') {
                ## Services not running, start them
                [array]$logOutput += "$service is not running, attempting to start..."
                [array]$logOutput += Start-LTService
                If ((Get-Service -Name $service).Status -ne 'Running') {
                    ## Failed to start services, try again
                    [array]$logOutput += Start-LTService
                    If ((Get-Service -Name $service).Status -ne 'Running') {
                        [array]$logOutput += "Failed to start $service again. Attempting a reinstall..."
                        $serviceStatus = 'Failed'
                        $reinstall = $true
                    } Else {
                        [array]$logOutput += "Successfully started $service!"
                        $serviceStatus = 'Success'
                    }
                } Else {
                    ## Starting services was successful
                    [array]$logOutput += "Successfully started $service!"
                    $serviceStatus = 'Success'
                }
            } Else {
                ## Services running
                [array]$logOutput += "Verified $service is running"
                $serviceStatus = 'Success'
            }
        }


        ## If the service is now running and we did not have to perform a service repair, check for last check-in date from reg
        If ($serviceStatus -eq 'Success' -and !$reinstall) {
            ## Verify the last check-in date is within the last day
            [datetime]$lastCheckin = (Get-ItemProperty -Path 'HKLM:\Software\Labtech\Service' -Name 'LastSuccessStatus').'LastSuccessStatus'
            If ($lastCheckin -gt (Get-Date).AddDays(-1)) {
                ## Check-in date looks good
                [array]$logOutput += "Confirmed the agent last checked in $lastCheckin which is inside the acceptable check-in range. Agent appears to be healthy!"
                $checkinStatus = 'Success'                    
            } Else {
                ## Check-in date is greater than 1 day
                [array]$logOutput += "The agent has not checked in for more than a day. Last check-in reported is $lastCheckin. Performing troubleshooting steps to find the root issue..."
                $checkinStatus = 'Failed'
            }            
        }


        ## Verify this machine is online
        If ($checkinStatus -eq 'Failed') {
            $internetCheck = Test-Connection 1.1.1.1 -EA 0
            $internetCheck2 = Test-Connection 8.8.8.8 -EA 0
            If (!$internetCheck -and !$internetCheck2) {
                $logOutput += "$env:COMPUTERNAME is unable to ping 1.1.1.1 and 8.8.8.8 so appears to be offline. This implies the agent is healthy, but further checks & troubleshooting methods rely on an internet connection, exiting script."
                [array]$logOutput = [array]$logOutput -join "`n"
                $logOutput
                $internetTest = 'Failed'
            }
        }


        ## If the machine has not checked in for more than a day, and the ping test to 1.1.1.1 and 8.8.8.8 has not failed, ping the Automate server
        If ($checkinStatus -eq 'Failed' -and !$internetTest) {
            ## Verify this machine can ping the Automate Server URL
            $automatePing = Test-Connection ($AutomateServerURL).replace('https://','')
            If ($automatePing) {
                ## Automate server ping was successful
                [array]$logOutput += "Verified $env:COMPUTERNAME is able to ping $AutomateServerURL. Attempting to clear local ports used for Automate agent check-in..."
                $automatePing = 'Success'
                [array]$logOutput += "Attempting to restart Automate services to see if the last successful connection to the server updates..."
                ## The Restart-LTService function has port check/clear built in
                [array]$logOutput += Restart-LTService
                ## Give the agent 2 minutes to get a new check-in date from the Automate server
                Start-Sleep -Seconds 120
                [datetime]$lastCheckin = (Get-ItemProperty -Path 'HKLM:\Software\Labtech\Service' -Name 'LastSuccessStatus').'LastSuccessStatus'
                If ($lastCheckin -lt (Get-Date).AddDays(-1)) {
                    $logOutput += "Agent still showing no successful check-ins to the Automate server after the service restart in the last day, allowing one more minute..."
                    Start-Sleep -Seconds 300
                    [datetime]$lastCheckin = (Get-ItemProperty -Path 'HKLM:\Software\Labtech\Service' -Name 'LastSuccessStatus').'LastSuccessStatus'
                    If ($lastCheckin -lt (Get-Date).AddDays(-1)) {
                        $logOutput += "Agent still showing no successful check-ins to the Automate server after the service restart in the last day, attempting reinstall..."
                        $reinstall = $true
                    } Else {
                        $logOutput += "Agent has now successfully checked in to $($AutomateServerURL)! Service restarts have restored connectivity."
                    }
                } Else {
                    $logOutput += "Agent has now successfully checked in to $($AutomateServerURL)! Service restarts have restored connectivity."
                }
            } Else {
                ## Automate server ping failed
                [array]$logOutput += "$env:COMPUTERNAME is unable to ping $($AutomateServerURL), unable to proceed with agent installation/repair/health check."
                $automatePing = 'Failed'
                Break
            }
        }

            
        ## If the machine has not checked in for more than 1 day, and the reinstall flag was set to true, then reinstall the agent, or, If the service status
        ## was Failed, reinstall the service.
        If ($checkinStatus -eq 'Failed' -and $reinstall -or $serviceStatus -eq 'Failed') {
            ## Reinstall Automate agent
            If ($serviceStatus -eq 'Failed') {
                $logOutput += "The Automate services failed to start, performing an agent reinstall..."
            } Else {
                $logOutput += "The check-in status was greater than 1 day ago, and a service restart did not resolve the issue, and the machine is online. Initiating an agent reinstall..."
            }
            ## Check for the last installation/reinstallation date of the Automate agent. Point being here is we don't want to spam reinstalls if it's not working.
            If ((Test-Path -Path $installDateFile -PathType Leaf)) {
                [datetime]$lastInstallDate = Get-Content -Path $installDateFile
                ## If it's been more than 1 day retry the install
                If ($lastInstallDate -gt (Get-Date).AddDays(-1)) {
                    [array]$logOutput += Reinstall-LTService -Server $AutomateServerURL -LocationID $LocationID -InstallerToken $InstallerToken -Force
                    Set-Content -Path $installDateFile -Value $curDate
                    If (!(Test-Path -Path $installCountFile -PathType Leaf)) {
                        Set-Content -Path $installCountFile -Value 1
                    } Else {
                        $installCount = Get-Content -Path $installCountFile
                        $installCount++
                        Set-Content -Path $installCountFile -Value $installCount
                    }
                } Else {
                    [array]$logOutput += "The script is calling for a reinstall but a reinstall was already attempted on $lastInstallDate. It must be 1+ days before a reinstall is attempted to avoid spamming the reinstall if it's not working."
                }
            } Else {
                [array]$logOutput += Reinstall-LTService -Server $AutomateServerURL -LocationID $LocationID -InstallerToken $InstallerToken -Force
                $logOutput += "Automate agent reinstall complete! The first check-in can take awhile to complete, so the next run of this script will check for heartbeat check-ins to verify all is functional."
                Set-Content -Path $installDateFile -Value $curDate
                If (!(Test-Path -Path $installCountFile -PathType Leaf)) {
                    Set-Content -Path $installCountFile -Value 1
                } Else {
                    $installCount = Get-Content -Path $installCountFile
                    $installCount++
                    Set-Content -Path $installCountFile -Value $installCount
                }
            }
        }
    } Else {
        Try {
            ## Automate agent is missing, install it
            [array]$logOutput += "$MSPName Automate Agent is missing, installing agent..."
            [array]$logOutput += Install-LTService -Server $AutomateServerURL -LocationID $LocationID -InstallerToken $InstallerToken -Force
            Set-Content -Path $installDateFile -Value $curDate
            If (!(Test-Path -Path $installCountFile -PathType Leaf)) {
                Set-Content -Path $installCountFile -Value 1
            } Else {
                $installCount = Get-Content -Path $installCountFile
                $installCount++
                Set-Content -Path $installCountFile -Value $installCount
            }
        } Catch {
            $logOutput += "There was an issue when attempting to install the Automate agent. Full error output: $Error"
        }
    }


    ## Format output to new lines per entry
    [array]$logOutput = [array]$logOutput -join "`n"
    $logOutput


    ## Log results to $agentHealthFile
    Add-Content -Path $agentHealthFile -Value $logOutput
}
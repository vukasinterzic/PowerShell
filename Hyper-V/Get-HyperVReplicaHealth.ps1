
#TODO Add Help
#TODO Add scheduled task creation switch and function
#TODO Add check for prerequisites
#TODO Use clustername instead of physical hosts
#TODO Add logpath parameter
#TODO Add e-mail sending part that is now missing
#TODO: Describe self-repairing options

<#script:

Function, with help

Steps:

1. Get list of clusters
2. Get list of Cluster Nodes
3. Get HyperV replica on each node in each cluster

if health not Normal (takze warning, critical), and State not replicating:
1. get error, copy, save to log
2. if state not replicating: start full replica
3. check again, if full replica running = no action
4. if full replica failed = send email, write to log


log everything

#pozadavky:
#ps4.0 nebo novejsi
#hyperv clusterning module management tools

#>


$PhysicalHosts = @("computername1")
$LogLimit = "182" #6 months
$LogPath = "C:\Users\admin.kpcs\Desktop"
$LogName = "HyperVReplicaScheduledTask.log"
$VMReplication = @()

$From = ""
$To = ""
$SMTPServer = ""
$EmailSubjectPart1 = "Hyper-V Replica Status: "


Function SayThis {

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string]$Color = "Cyan",


        [Parameter(Mandatory = $false,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $false)]
        [switch]$WriteToLog

    )     

    Write-Host -ForegroundColor $Color $Message
    
    if ($WriteToLog) {
        "$(Get-Date -Format s): $Message" | Out-File -FilePath "$LogPath\$LogName" -Append
    }
}




<#

Logic behind the log files:
- current log - age up to $LogLimit
- previous log - created by renaming current log that was older than $LogLimit
- previous log is deleted before current log is renamed. therefore only 2 logs are kept, up to 2x $logLimit

#>


if (Test-Path "$LogPath\$LogName") {

    if (Test-Path -Path "$LogPath\$LogName" -OlderThan ((Get-Date).AddDays(-$LogLimit))) {
        SayThis -Message "Log file $LogName is older than configured limit of $LogLimit days, file will be renamed and new file will be created." -WriteToLog
        
        $OldLog = Get-ChildItem -Path $LogPath | Where-Object Name -like "$($LogName.Split(".")[0])-*"

        if ($OldLog) {

            Remove-Item -Path "$LogPath\$($OldLog.Name)" -Force
            SayThis -Message "Old log file $($OldLog.Name) was removed." -WriteToLog
            
        }

        
        SayThis -Message "######## END OF LOG FILE ########" -WriteToLog

        $NewLogName = "HyperVReplicaScheduledTask-$((Get-Date).AddDays(-$LogLimit).ToString('ddMMyy'))-$(Get-Date -format ddMMyy).log"
        Rename-Item -Path "$LogPath\$LogName" -NewName $NewLogName  -Force

        Start-Sleep -Seconds 5
        
        New-Item -ItemType File -Path "$LogPath\$LogName"
        
        Start-Sleep -Seconds 5

        SayThis -Message "######## START OF NEW LOG FILE ########`r`n" -WriteToLog
        SayThis -Message "Previous log file was renamed to $NewLogName" -WriteToLog
    }



} else {
    SayThis -Message "Log file does not exist. Creating new file."

    New-Item -ItemType File -Path "$LogPath\$LogName"
        
    Start-Sleep -Seconds 5
    
    SayThis -Message "######## START OF NEW LOG FILE ########`r`n" -WriteToLog
    SayThis -Message "New log file was created because log file did not exist.`r`n" -WriteToLog
}


SayThis -Message "[#][#][#] Start of the scheduled run [#][#][#]" -WriteToLog


foreach ($PhysicalHost in $PhysicalHosts) {
    
    SayThis -Message "Getting the list of replicated VMs on physical host $PhysicalHost ..."
    $VMReplication += Get-VM -ComputerName $PhysicalHost | Where-Object ReplicationMode -eq Primary | Get-VMReplication #| Select-Object -Property *

}


if ($VMReplication) {



$EmailBody = "<br>"
$EmailBody += "<strong>Script Report: Disable Inactive Users:</strong>"
$EmailBody += "<br><br>"

    SayThis -Message "VMs with enabled Hyper-V Replica discovered." -WriteToLog

    SayThis -Message "Selecting all VMs that are currently not replicating..."
    $VMReplicationError = $VMReplication | Where-Object State -ne "Replicating"

    SayThis -Message "Selecting all VMs that are replicating with warning..."
    $VMReplicationWarning = $VMReplication | Where-Object {$_.State -eq "Replicating" -and $_.Health -ne "Normal"}

} else {

    SayThis -Message "There are no VMs with enabled Hyper-V Replica. Nothing to do." -WriteToLog

}

$RetryCount = 0

while ($RetryCount -lt 5) {

$RetryCount++
$FixedVMs = @()



    if (@($VMReplicationError).Count -gt 0) {

        SayThis -Message "VMs that are currently not replicating:" -WriteToLog
        $VMReplicationError | ForEach-Object {SayThis -Message $_.VMName -WriteToLog}

        SayThis -Message "Performing check $RetryCount/5 ..." -WriteToLog
    
        foreach ($VM in $VMReplicationError) {

            SayThis -Message "Processing VM $($VM.VMName)..." -WriteToLog


            switch ($($VM.State)) {

                {($_ -like "*Error*") -or ($_ -like "*WaitingForStartResynchronize*")} {

                    SayThis "VM replication of $($VM.VMName) is in state $($VM.State). Attempting to start re-synchronization..." -WriteToLog

                    Resume-VMReplication -ComputerName $VM.PrimaryServer -VMName $VM.VMName -Resynchronize -Verbose

                    $FixedVMs += $VM
                
                }


                {($_ -like "*FailOverWaitingCompletion*") -or ($_ -like "*FailedOver*")} {
    
                    SayThis "VM replication of $($VM.VMName) is in state $($VM.State) which indicates that failover was initiated or completed. No action will be taken." -WriteToLog
        
                }

                {($_ -like "*Resynchronizing*") -or ($_ -like "*SyncedReplicationComplete*")} {
                
                    SayThis "VM replication of $($VM.VMName) is in state $($VM.State). No action will be taken." -WriteToLog

                }

                {($_ -like "*ResynchronizeSuspended*") -or ($_ -like "*Suspended*")} {

                    SayThis "VM replication of $($VM.VMName) is in state $($VM.State). E-Mail notification will be sent." -WriteToLog

                }

                "WaitingForInitialReplication" {

                    SayThis "VM replication of $($VM.VMName) is in state $($VM.State). Attempting to start initial replica..." -WriteToLog

                    Start-VMInitialReplication -ComputerName $VM.PrimaryServer -VMName $VM.VMName -Verbose 

                    $FixedVMs += $VM

                }

            } #end of switch

        } #end of foreach

    } else { #End of VMReplicationError
    
    $RetryCount = 5 #to make sure that loop does not repeat if there is nothing to fix
    
    }




    if ((@($FixedVMs).Count -gt 0) -and ($RetryCount -lt 5)) {
            
        $VMReplicationError = @()
        $VMReplication = @()

        foreach ($FixedVM in $FixedVMs) {

            $VMReplication += Get-VMReplication -ComputerName $FixedVM.PrimaryServer -VMName $FixedVM.VMName

        }

        $VMReplicationError = $VMReplication | Where-Object State -ne "Replicating"

        SayThis -Message "Waiting 5 minutes before performing status check again..." -WriteToLog
        Start-Sleep -Seconds 300

    } elseif ((@($FixedVMs).Count -gt 0) -and ($RetryCount -eq 5)) { #while loop is running for the last time and it will not repeat any more
        
        $VMReplicationError = @()
        $VMReplication = @()

        foreach ($FixedVM in $FixedVMs) {

            $VMReplication += Get-VMReplication -ComputerName $FixedVM.PrimaryServer -VMName $FixedVM.VMName

        }

        $VMReplicationError = $VMReplication | Where-Object State -ne "Replicating"


    }

}#end of while

        
If (@($VMReplicationWarning).Count -gt 0) {

    $VMReplicationWarnings = @()

    SayThis -Message "VMs that are currently replicating with warning:" -WriteToLog
    $VMReplicationWarning | ForEach-Object {SayThis -Message $_.VMName -WriteToLog}
    
    foreach ($VM in $VMReplicationWarning) {

        $VMReplicationWarnings += Measure-VMReplication -ComputerName $VM.PrimaryServer -VMName $VM.VMName | Select-Object Name, ReplicationHealth, ReplicationHealthDetails 

    }

} 


If (($VMReplication) -and (@($VMReplicationError).Count -eq 0) -and (@($VMReplicationWarning).Count -eq 0)) {

    SayThis -Message "All VMs are replicating properly." -WriteToLog

}


SayThis -Message "[#][#][#] The end of the scheduled run [#][#][#]`r`n" -WriteToLog
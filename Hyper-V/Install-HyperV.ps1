<#
 - Downloads NuGet package provider
 - Installs the DscResource and xHyper-V PS modules in support of the upcoming DSC Extenion run in HyperVHostConfig.ps1
 - Installs Hyper-V with all Features and Management Tools and then Restarts the Machine
#>

Set-ExecutionPolicy Unrestricted -Force
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Find-Module -Includes DscResource -Name xHyper-v | Install-Module -Force

#Install Hyper-V and Reboot
Install-WindowsFeature -Name Hyper-V `
                       -IncludeAllSubFeature `
                       -IncludeManagementTools `
                       -Verbose `
                       -Restart


#FIXME Change it, without external dependencies
#TODO Add nested virtualization DSC
#TODO Add Azure option
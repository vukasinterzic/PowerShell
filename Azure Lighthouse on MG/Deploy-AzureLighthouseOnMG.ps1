<#
.SYNOPSIS
Deploys Azure Lighthouse policy to a management group with automated remediation.

.DESCRIPTION
This script deploys an Azure Policy definition that automatically enables Azure Lighthouse 
delegated management for subscriptions under a specified management group. It creates a 
policy assignment with a system-assigned managed identity, grants it Owner role permissions, 
and initiates a remediation task to deploy Lighthouse across all subscriptions.

.PARAMETER ManagementGroupName
The name or ID of the management group where the policy will be deployed.

.PARAMETER TemplatePath
Path or URI to the ARM template file containing the policy definition.

.PARAMETER ParametersPath
Path or URI to the parameters file containing policy and deployment configuration values.

.PARAMETER DeploymentLocation
Azure region for the deployment. Defaults to 'eastus'.

.EXAMPLE
.\Deploy-AzureLighthouseOnMG.ps1 -ManagementGroupName "MyMG" `
    -TemplatePath ".\deployLighthouseIfNotExistManagementGroup.json" `
    -ParametersPath ".\deployLighthouseIfNotExistsManagementGroup.parameters.json"

.NOTES
- Requires Azure PowerShell modules (Az.Accounts, Az.ManagedServiceIdentity, Az.Policy)
- User must have Owner role on the management group
- The script registers Microsoft.ManagedServices provider in all subscriptions

.AUTHOR
Vukasin Terzic - https://azureis.fun

#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$ManagementGroupName,

	[Parameter(Mandatory = $true)]
	[string]$TemplatePath,

	[Parameter(Mandatory = $true)]
	[string]$ParametersPath,

	[Parameter(Mandatory = $false)]
	[string]$DeploymentLocation = "eastus"  # optional (default eastus)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Line($msg) { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" }

try {
	Write-Line "Checking Azure context..."
	$ctx = Get-AzContext -ErrorAction SilentlyContinue
	if (-not $ctx) { Connect-AzAccount | Out-Null }

	Write-Line "Validating management group '$ManagementGroupName'..."
	$mg = Get-AzManagementGroup -GroupId $ManagementGroupName -Expand -Recurse

	Write-Line "Discovering subscriptions under management group..."
	function Get-Subs($mgObj) {
		$subs = @()
		foreach ($child in ($mgObj.Children | Where-Object { $_ })) {
			if ($child.Type -eq '/subscriptions') { $subs += $child }
			elseif ($child.Type -like '*managementGroups*') {
				$childMg = Get-AzManagementGroup -GroupId $child.Name -Expand
				$subs += Get-Subs -mgObj $childMg
			}
		}
		return $subs
	}
	$subscriptions = Get-Subs -mgObj $mg
	Write-Line "Subscriptions found: $($subscriptions | Measure-Object | Select-Object -ExpandProperty Count)"

	Write-Line "Ensuring Microsoft.ManagedServices is registered in each subscription..."
	foreach ($s in $subscriptions) {
		Set-AzContext -SubscriptionId $s.Name | Out-Null
		$provider = Get-AzResourceProvider -ProviderNamespace Microsoft.ManagedServices
		if ($provider.RegistrationState -ne 'Registered') {
			Write-Line "Registering in $($s.DisplayName)..."
			Register-AzResourceProvider -ProviderNamespace Microsoft.ManagedServices | Out-Null
		}
	}

	Write-Line "Validating template paths..."
	if ($TemplatePath -notmatch '^https?://') { if (-not (Test-Path $TemplatePath)) { throw "Template not found: $TemplatePath" } }
	if ($ParametersPath -notmatch '^https?://') { if (-not (Test-Path $ParametersPath)) { throw "Parameters not found: $ParametersPath" } }

	Write-Line "Deploying ARM template to management group..."
	$deploymentName = "AzureLighthouse-$(Get-Date -Format 'yyyyMMddHHmmss')"
	$deployParams = @{
		Name = $deploymentName
		ManagementGroupId = $ManagementGroupName
		Location = $DeploymentLocation
		ErrorAction = 'Stop'
	}
	if ($TemplatePath -match '^https?://') { $deployParams.TemplateUri = $TemplatePath } else { $deployParams.TemplateFile = $TemplatePath }
	if ($ParametersPath -match '^https?://') { $deployParams.TemplateParameterUri = $ParametersPath } else { $deployParams.TemplateParameterFile = $ParametersPath }
	$deployment = New-AzManagementGroupDeployment @deployParams
	Write-Line "Deployment state: $($deployment.ProvisioningState)"

	Write-Line "Retrieving policy definition created by template..."
	# Extract policy displayName from parameters file (resolved value)
	if ($ParametersPath -match '^https?://') {
		$paramsContent = (Invoke-WebRequest -Uri $ParametersPath -UseBasicParsing).Content
	} else {
		$paramsContent = Get-Content -Path $ParametersPath -Raw
	}
	$params = $paramsContent | ConvertFrom-Json
	$policyDisplayName = $params.parameters.displayName.value
	if (-not $policyDisplayName) { throw "displayName parameter not found in parameters file." }
	
	Write-Line "Looking for policy with display name: '$policyDisplayName'"
	$policyDef = Get-AzPolicyDefinition -ManagementGroupName $ManagementGroupName | Where-Object DisplayName -eq $policyDisplayName | Select-Object -First 1
	if (-not $policyDef) { throw "Policy definition not found with display name: $policyDisplayName" }

	Write-Line "Assigning policy to management group with managed identity..."
	$scope = "/providers/Microsoft.Management/managementGroups/$ManagementGroupName"
	$assignmentName = "Lighthouse-$(Get-Date -Format 'yyyyMMdd')"
	$assignment = New-AzPolicyAssignment `
		-Name $assignmentName `
		-DisplayName "$policyDisplayName Assignment" `
		-Scope $scope `
		-PolicyDefinition $policyDef `
		-Location $DeploymentLocation `
		-IdentityType 'SystemAssigned'
	
	Write-Line "Waiting for assignment to propagate..."
	Start-Sleep -Seconds 10
	
	# Retrieve the assignment to ensure we have the full object with ResourceId
	$assignment = Get-AzPolicyAssignment -Name $assignmentName -Scope $scope

	Write-Line "Granting Owner role to managed identity on management group..."
	New-AzRoleAssignment `
		-ObjectId $assignment.IdentityPrincipalId `
		-RoleDefinitionName "Owner" `
		-Scope "/providers/Microsoft.Management/managementGroups/$ManagementGroupName" `
		-ErrorAction SilentlyContinue | Out-Null

	Write-Line "Creating remediation task..."
	$remediationName = "AzureLighthouse-Remediate-$(Get-Date -Format 'yyyyMMddHHmmss')"
	$remediation = Start-AzPolicyRemediation -Name $remediationName -ManagementGroupName $ManagementGroupName -PolicyAssignmentId $assignment.Id

	Write-Line "Monitoring remediation (up to 10 minutes)..."
	$elapsed = 0; $interval = 15; $limit = 600
	do {
		Start-Sleep -Seconds $interval; $elapsed += $interval
		$status = Get-AzPolicyRemediation -Name $remediationName -ManagementGroupName $ManagementGroupName -ErrorAction SilentlyContinue
		if ($status) { Write-Line "State: $($status.ProvisioningState) Success: $($status.DeploymentSummary.SuccessfulDeployments) Failed: $($status.DeploymentSummary.FailedDeployments)" }
	} while ($status -and $status.ProvisioningState -notin @('Succeeded','Failed','Canceled') -and $elapsed -lt $limit)

	Write-Line "Done. Policy definition, assignment, and remediation completed." 
	Write-Line "Deployment: $deploymentName | Assignment: $($assignment.Name) | Remediation: $remediationName"
}
catch {
	Write-Line "Error: $($_.Exception.Message)"
	if ($_.ScriptStackTrace) { Write-Line "Stack: $($_.ScriptStackTrace)" }
	throw
}

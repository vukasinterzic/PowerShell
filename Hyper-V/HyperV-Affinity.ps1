#Configuration of Anti-Affinity on HyperV Cluster:

Get-ClusterGroup | Select-Object Name, AntiAffinityClassNames

$AntiAffinityGroupName = New-Object System.Collections.Specialized.StringCollection

$AntiAffinityGroupName.Add("AffinityGroup Description")

(Get-ClusterGroup -Name "VM1").AntiAffinityClassNames = $AntiAffinityGroupName
(Get-ClusterGroup -Name "VM2").AntiAffinityClassNames = $AntiAffinityGroupName
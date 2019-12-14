 

Function Remove-UserFromGroup ()
{

    param
    (
        [Parameter(Mandatory=$true)] [string] $User,
        [Parameter(Mandatory=$true)] [string] $Group
    )

    $Groups = Get-AzureADGroup -SearchString "$Group" #It will search for all groups that contain the string
    $GroupToRemove = $Groups | Where-Object DisplayName -EQ $Group #Select unique result

    $UserToRemove = Get-AzureADUser -ObjectId $User


    SayThis -Color Gray -Message "Detecting the group type ..."       
    
    $GroupType = Get-MsolGroup -ObjectId $GroupToRemove.ObjectId | Select-Object -ExpandProperty GroupType

    if ($GroupType -eq "DistributionList") {
        if (Get-UnifiedGroup -Identity $GroupToRemove.ObjectId) {
            $GroupType = "Office365"
        }
    }

    SayThis -Color Gray -Message "Group $($GroupToAdd.DisplayName) is $($GroupType)."

    Try {

 
        switch ($GroupType) {
            {"Office365" -contains $_} {Remove-UnifiedGroupLinks -Identity $GroupToRemove.ObjectId -Links $UserToRemove.UserPrincipalName -LinkType Members -Confirm:$false}
            {"Security" -contains $_} {Remove-MsolGroupMember -GroupObjectId $GroupToRemove.ObjectId -GroupMemberObjectId $UserToRemove.ObjectId -GroupMemberType User -ErrorAction SilentlyContinue}
            {"DistributionList","MailEnabledSecurity" -contains $_} {Remove-DistributionGroupMember -Identity $GroupToRemove.ObjectId -Member $UserToRemove.ObjectId -Confirm:$false -BypassSecurityGroupManagerCheck:$true}
            #"SharedMailbox" {}
            Default {SayThis -Color Magenta -Message "Group type $GroupType is not supported!" -WriteToLog}
        }

        SayThis -Color Cyan -Message "Successfuly removed $($UserToRemove.UserPrincipalName) from the group $($GroupToRemove.DisplayName)"
        
    }

    Catch {

        SayThis -Color Magenta -Message "Failed removing $($UserToRemove.UserPrincipalName) from the group $($GroupToRemove.DisplayName)"
        
    }

}
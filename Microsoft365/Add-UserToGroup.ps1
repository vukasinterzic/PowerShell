 Function Add-UserToGroup ()
{

    param
    (
        [Parameter(Mandatory=$true)] [string] $User,
        [Parameter(Mandatory=$true)] [string] $Group
    )

    $Groups = Get-AzureADGroup -SearchString "$Group" #It will search for all groups that contain the string
    $GroupToAdd = $Groups | Where-Object DisplayName -EQ $Group #Select unique result

    $UserToAdd = Get-AzureADUser -ObjectId $User


    SayThis -Color Gray -Message "Detecting the group type ..."       
    
    $GroupType = Get-MsolGroup -ObjectId $GroupToAdd.ObjectId | Select-Object -ExpandProperty GroupType

    if ($GroupType -eq "DistributionList") {
        if (Get-UnifiedGroup -Identity $GroupToAdd.ObjectId) {
            $GroupType = "Office365"
        }
    }

    SayThis -Color Gray -Message "Group $($GroupToAdd.DisplayName) is $($GroupType)."

    Try {

 
        switch ($GroupType) {
            {"Office365" -contains $_} {Add-UnifiedGroupLinks -Identity $GroupToAdd.ObjectId -Links $UserToAdd.UserPrincipalName -LinkType Members -Confirm:$false}
            {"Security" -contains $_} {Add-MsolGroupMember -GroupObjectId $GroupToAdd.ObjectId -GroupMemberObjectId $UserToAdd.ObjectId -GroupMemberType User -ErrorAction SilentlyContinue}
            {"DistributionList","MailEnabledSecurity" -contains $_} {Add-DistributionGroupMember -Identity $GroupToAdd.ObjectId -Member $UserToAdd.ObjectId -Confirm:$false -BypassSecurityGroupManagerCheck:$true}
            #"SharedMailbox" {}
            Default {SayThis -Color Magenta -Message "Group type $GroupType is not supported!" -WriteToLog}
        }
        
        SayThis -Color Cyan -Message "Successfuly added $($UserToAdd.UserPrincipalName) to the group $($GroupToAdd.DisplayName)"
        
    }

    Catch {

        SayThis -Color Magenta -Message "Failed adding $($UserToAdd.UserPrincipalName) to the group $($GroupToAdd.DisplayName)"
        
    }

} 

#TODO Add authentication and description
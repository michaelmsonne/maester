﻿<#
.SYNOPSIS
    Checks if Global Admins are cloud users

.DESCRIPTION

    Privileged users SHALL be provisioned cloud-only accounts separate from an on-premises directory or other federated identity providers.

.EXAMPLE
    Test-MtCisaCloudGlobalAdmin

    Returns true if all global admins are cloud users
#>

Function Test-MtCisaCloudGlobalAdmin {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $role = Get-MtRole | Where-Object {`
        $_.id -eq "62e90394-69f5-4237-9190-012177145e10" }

    $assignments = Get-MtRoleMember -roleId $role.id -Active

    $globalAdministrators = $assignments | Where-Object {`
        $_.'@odata.type' -eq "#microsoft.graph.user"
    }

    $body = @{
        requests = @()
    }
    $requests = @()
    $i = 0
    foreach($admin in $globalAdministrators){
        $request = @{
            id     = "$i"
            method = "GET"
            url    = "/users/$($admin.id)?`$select=id,displayName,onPremisesSyncEnabled"
        }
        $requests += $request
        $i++
    }
    $body.requests = $requests

    $usersSplat = @{
        Method     = "POST"
        Body       = $($body|ConvertTo-Json)
        Uri        = "https://graph.microsoft.com/v1.0/`$batch"
        OutputType = "PSObject"
    }
    $users = (Invoke-MgGraphRequest @usersSplat).responses.body

    $result = $users | Where-Object {`
        $_.onPremisesSyncEnabled -eq $true
    }

    $testResult = ($result|Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no hybrid Global Administrators."
    } else {
        $testResultMarkdown = "Your tenant has 1 or more hybrid Global Administrators:`n`n%TestResult%"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType Users -GraphObjects $result

    return $testResult
}
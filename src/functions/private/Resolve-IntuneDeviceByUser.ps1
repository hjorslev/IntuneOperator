function Resolve-IntuneDeviceByUser {
    <#
    .SYNOPSIS
    Resolves one or more Intune managed devices by primary user UPN.

    .DESCRIPTION
    Queries Intune managed devices using the userPrincipalName filter.
    Performs case-insensitive exact match searching via OData filter.
    Returns all devices assigned to the specified user.

    .PARAMETER UserPrincipalName
    The UPN of the primary user to search for in Intune managed devices.

    .EXAMPLE
    Resolve-IntuneDeviceByUser -UserPrincipalName "jane.doe@contoso.com"

    Returns all managed device objects whose primary user is jane.doe@contoso.com.

    .INPUTS
    System.String

    .OUTPUTS
    PSCustomObject[]

    .NOTES
    Part of the Intune Device helper functions.
    Uses Microsoft Graph /beta endpoint.
    Requires DeviceManagementManagedDevices.Read.All scope.
    #>

    [OutputType([PSCustomObject[]])]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "The UPN of the primary user to resolve"
        )]
        [ValidateNotNullOrEmpty()]
        [string]$UserPrincipalName
    )

    begin {
        $baseUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'
        $select = 'id,deviceName,userPrincipalName,manufacturer,model,operatingSystem,serialNumber,complianceState,lastSyncDateTime'
    }

    process {
        # Escape only the string literal; keep OData filter syntax intact.
        $escapedUpn = $UserPrincipalName.Replace("'", "''")
        $filter = "userPrincipalName eq '$escapedUpn'"

        # Ordered fallback chain matching the BadRequest resilience pattern used elsewhere.
        $candidateUris = @(
            "$baseUri`?`$filter=$filter&`$select=$select",
            "$baseUri`?`$filter=$filter",
            "$baseUri`?`$select=$select",
            $baseUri
        )

        $resp = $null
        $lastBadRequestError = $null

        foreach ($candidateUri in $candidateUris) {
            try {
                $resp = Invoke-GraphGet -Uri $candidateUri
                break
            } catch {
                $errorMessage = $_.Exception.Message
                if ($errorMessage -match 'BadRequest|400') {
                    $lastBadRequestError = $_
                    Write-Verbose -Message "Managed device query returned BadRequest for URI '$candidateUri'. Trying next fallback."
                    continue
                }

                # Non-BadRequest errors are fatal; re-throw immediately.
                throw
            }
        }

        # All candidates failed with BadRequest; surface the last error.
        if ($null -eq $resp -and $null -ne $lastBadRequestError) {
            throw $lastBadRequestError
        }

        # Normalise response: unwrap .value collection or treat as single object.
        $devices = @()
        if ($null -ne $resp) {
            if ($null -ne $resp.value) {
                $devices = @($resp.value)
            } else {
                $devices = @($resp)
            }
        }

        # Apply exact match locally to handle unfiltered fallback responses.
        $matchedDevices = @($devices | Where-Object -FilterScript { [string]$_.userPrincipalName -ieq $UserPrincipalName })

        if ($matchedDevices.Count -eq 0) {
            Write-Verbose -Message "No managed devices found for userPrincipalName '$UserPrincipalName'."
            return [PSCustomObject[]]@()
        }

        # Return managed device objects with fields required by downstream callers.
        $matchedDevices | ForEach-Object -Process {
            [PSCustomObject]@{
                id                = $_.id
                deviceName        = $_.deviceName
                userPrincipalName = $_.userPrincipalName
                manufacturer      = $_.manufacturer
                model             = $_.model
                operatingSystem   = $_.operatingSystem
                serialNumber      = $_.serialNumber
                complianceState   = $_.complianceState
                lastSyncDateTime  = $_.lastSyncDateTime
            }
        }
    } # Process
} # Cmdlet

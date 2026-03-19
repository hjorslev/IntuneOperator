function Resolve-IntuneDeviceByName {
    <#
    .SYNOPSIS
    Resolves one or more Intune managed devices by device name.

    .DESCRIPTION
    Queries Intune managed devices using the device name filter.
    Performs case-insensitive exact match searching via OData filter.
    Returns all devices matching the specified name.

    .PARAMETER Name
    The device name to search for in Intune managed devices.

    .EXAMPLE
    Resolve-IntuneDeviceByName -Name "PC-001"

    Returns the managed device object matching the name "PC-001", if found.

    .INPUTS
    System.String

    .OUTPUTS
    PSObject[]

    .NOTES
    Part of the Intune Device Login helper functions.
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
            HelpMessage = "The device name to resolve"
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    begin {
        $baseUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'
    }

    process {
        # Escape only the string literal content; keep OData filter syntax intact.
        $escapedName = $Name.Replace("'", "''")
        $filter = "deviceName eq '$escapedName'"
        $select = 'id,deviceName,userPrincipalName,manufacturer,model,operatingSystem,serialNumber,enrolledByUserId,complianceState,lastSyncDateTime'
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

                throw
            }
        }

        if ($null -eq $resp -and $null -ne $lastBadRequestError) {
            throw $lastBadRequestError
        }

        $devices = @()
        if ($null -ne $resp) {
            if ($null -ne $resp.value) {
                $devices = @($resp.value)
            } else {
                $devices = @($resp)
            }
        }

        # Keep exact name semantics even after fallback to unfiltered Graph query.
        $matchedDevices = @($devices | Where-Object -FilterScript { [string]$_.deviceName -ieq $Name })

        if ($matchedDevices.Count -eq 0) {
            Write-Verbose -Message "No managed devices found with deviceName '$Name'."
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
                enrolledByUserId  = $_.enrolledByUserId
                complianceState   = $_.complianceState
                lastSyncDateTime  = $_.lastSyncDateTime
            }
        }
    } # Process
} # Cmdlet

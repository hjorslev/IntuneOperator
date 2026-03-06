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
        # deviceName is case-insensitive in OData. Exact match.
        $encoded = [uri]::EscapeDataString("deviceName eq '$Name'")
        $uri = "$baseUri`?`$filter=$encoded"

        $resp = Invoke-GraphGet -Uri $uri

        if ($null -eq $resp.value -or $resp.value.Count -eq 0) {
            Write-Verbose "No managed devices found with deviceName '$Name'."
            return @()
        }

        return $resp.value
    }
}

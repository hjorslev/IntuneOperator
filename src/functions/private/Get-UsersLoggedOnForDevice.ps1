function Get-UsersLoggedOnForDevice {
    <#
    .SYNOPSIS
    Retrieves logged-on user information for an Intune managed device.

    .DESCRIPTION
    Queries a specific managed device by DeviceId and retrieves the usersLoggedOn collection.
    Returns the complete device object including all logged-on user entries.

    .PARAMETER Id
    The Intune managed device identifier (GUID).

    .EXAMPLE
    Get-UsersLoggedOnForDevice -Id "c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a"

    Returns the device object with usersLoggedOn collection for the specified device ID.

    .INPUTS
    System.String

    .OUTPUTS
    PSObject

    .NOTES
    Part of the Intune Device Login helper functions.
    Uses Microsoft Graph /beta endpoint where usersLoggedOn is available.
    Requires DeviceManagementManagedDevices.Read.All scope.
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "The managed device ID (GUID)"
        )]
        [ValidatePattern('^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$')]
        [string]$Id
    )

    begin {
        $baseUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'
    }

    process {
        $uri = "$baseUri/$Id"
        Invoke-GraphGet -Uri $uri
    }
}

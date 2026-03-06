function Resolve-EntraUserById {
    <#
    .SYNOPSIS
    Resolves an Entra ID user by user ID to retrieve user principal name and other details.

    .DESCRIPTION
    Queries Microsoft Graph for a specific user by their user ID (object ID).
    Returns user object including userPrincipalName for reporting and audit purposes.
    Handles cases where user may no longer exist in Entra ID.

    .PARAMETER UserId
    The Entra ID user object identifier (GUID).

    .EXAMPLE
    Resolve-EntraUserById -UserId "d1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a"

    Returns the user object with UPN for the specified user ID.

    .INPUTS
    System.String

    .OUTPUTS
    PSObject

    .NOTES
    Part of the Intune Device Login helper functions.
    Uses Microsoft Graph /v1.0 endpoint.
    Requires User.Read.All scope.
    Returns a minimal user object if user cannot be found.
    #>

    [OutputType([PSObject])]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "The Entra ID user object ID"
        )]
        [ValidateNotNullOrEmpty()]
        [string]$UserId
    )

    begin {
        $baseUri = 'https://graph.microsoft.com/v1.0/users'
    }

    process {
        $uri = "$baseUri/$UserId"
        try {
            Invoke-GraphGet -Uri $uri
        } catch {
            Write-Verbose "Could not resolve user ID '$UserId': $($_.Exception.Message)"
            # Return a minimal object with the ID and a placeholder UPN
            [PSCustomObject]@{
                id                = $UserId
                userPrincipalName = "Unknown (ID: $UserId)"
            }
        }
    }
}

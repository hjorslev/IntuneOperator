function Invoke-GraphGet {
    <#
    .SYNOPSIS
    Invokes a GET request against the Microsoft Graph API with error handling.

    .DESCRIPTION
    Wrapper function for making authenticated GET requests to the Microsoft Graph API.
    Provides consistent error handling and verbose output for all Graph API calls.
    Requires an established Microsoft Graph connection via Connect-MgGraph.

    .PARAMETER Uri
    The full URI of the Graph API endpoint to query.

    .EXAMPLE
    Invoke-GraphGet -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices"

    Retrieves all managed devices from the Graph API.

    .INPUTS
    System.String

    .OUTPUTS
    PSObject

    .NOTES
    Part of the Intune Device Login helper functions.
    Requires Microsoft.Graph PowerShell module with active connection.
    #>

    [OutputType([PSObject])]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "The full URI of the Graph API endpoint"
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Uri
    )

    process {
        Write-Verbose "GET $Uri"
        try {
            $splat = @{
                Method      = 'GET'
                Uri         = $Uri
                ErrorAction = 'Stop'
            }
            Invoke-MgGraphRequest @splat
        } catch {
            throw "Graph request failed for '$Uri': $($_.Exception.Message)"
        }
    }
}

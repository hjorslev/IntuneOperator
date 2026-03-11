function Invoke-GraphGet {
    <#
    .SYNOPSIS
    Invokes a GET request against the Microsoft Graph API with error handling and automatic pagination.

    .DESCRIPTION
    Wrapper function for making authenticated GET requests to the Microsoft Graph API.
    Provides consistent error handling, verbose output, and automatic pagination handling for all Graph API calls.
    When the response contains a 'value' collection and '@odata.nextLink', automatically follows pagination
    to retrieve all results.

    Requires an established Microsoft Graph connection via Connect-MgGraph.

    .PARAMETER Uri
    The full URI of the Graph API endpoint to query.

    .EXAMPLE
    Invoke-GraphGet -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices"

    Retrieves all managed devices from the Graph API, automatically following pagination links.

    .EXAMPLE
    Invoke-GraphGet -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/12345"

    Retrieves a single managed device by ID (no pagination applies).

    .INPUTS
    System.String

    .OUTPUTS
    PSObject

    .NOTES
    Part of the Intune Device Login helper functions.
    Requires Microsoft.Graph PowerShell module with active connection.
    Automatically handles pagination for collection responses.
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
        Write-Verbose -Message "GET $Uri"
        try {
            $splat = @{
                Method      = 'GET'
                Uri         = $Uri
                ErrorAction = 'Stop'
            }
            $response = Invoke-MgGraphRequest @splat

            # Check if response has pagination (value collection with nextLink)
            if ($null -ne $response.value -and $null -ne $response.'@odata.nextLink') {

                Write-Verbose -Message "Response contains pagination, retrieving all pages"
                $allValues = [System.Collections.Generic.List[object]]::new()
                $allValues.AddRange($response.value)

                $nextLink = $response.'@odata.nextLink'
                $pageCount = 1

                while ($null -ne $nextLink) {
                    $pageCount++
                    Write-Verbose -Message "Following pagination link (page $pageCount, current items: $($allValues.Count))"

                    $splat.Uri = $nextLink
                    $nextResponse = Invoke-MgGraphRequest @splat

                    if ($null -ne $nextResponse.value) {
                        $allValues.AddRange($nextResponse.value)
                    }

                    $nextLink = $nextResponse.'@odata.nextLink'
                }

                Write-Verbose -Message "Pagination complete: retrieved $($allValues.Count) total items across $pageCount pages"

                # Return modified response with all values
                $response.value = $allValues.ToArray()
                $response.PSObject.Properties.Remove('@odata.nextLink')
            }

            return $response

        } catch {
            $Exception = [Exception]::new("Graph request failed for '$Uri': $($_.Exception.Message)", $_.Exception)
            $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                $Exception,
                'GraphRequestFailed',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $Uri
            )
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
    } # Process
} # Cmdlet

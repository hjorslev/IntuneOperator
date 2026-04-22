function ConvertTo-IntuneDeviceSummary {
    <#
    .SYNOPSIS
    Converts a managed device Graph object to the module's Intune device summary shape.

    .DESCRIPTION
    Maps selected managed device properties to a stable output object used by Get-IntuneDevice.
    Expects any enrichment (for example EnrolledBy resolution) to be done before conversion.

    .PARAMETER Device
    A Microsoft Graph managed device object.

    .EXAMPLE
    $device | ConvertTo-IntuneDeviceSummary

    Converts each input device object to the standardized output object.

    .INPUTS
    System.Object

    .OUTPUTS
    PSCustomObject
    #>

    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [object]$Device
    )

    process {
        $lastSyncDateTime = $null
        # Keep output type stable even if Graph returns an unexpected timestamp format.
        if ($null -ne $Device.lastSyncDateTime -and -not [string]::IsNullOrWhiteSpace([string]$Device.lastSyncDateTime)) {
            try {
                $lastSyncDateTime = [datetime]$Device.lastSyncDateTime
            } catch {
                $lastSyncDateTime = $null
            }
        }

        # Stable output contract consumed by Get-IntuneDevice callers.
        [PSCustomObject]@{
            DeviceName         = [string]$Device.deviceName
            PrimaryUser        = [string]$Device.userPrincipalName
            DeviceManufacturer = [string]$Device.manufacturer
            DeviceModel        = [string]$Device.model
            OperatingSystem    = [string]$Device.operatingSystem
            SerialNumber       = [string]$Device.serialNumber
            Compliance         = [string]$Device.complianceState
            LastSyncDateTime   = $lastSyncDateTime
        }
    } # Process
} # Cmdlet

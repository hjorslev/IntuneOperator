function Get-FirstPropertyValue {
    <#
    .SYNOPSIS
    Returns the first non-empty property value from an object or dictionary.

    .DESCRIPTION
    Checks each property name in order against the input object, dictionary keys,
    and an AdditionalProperties dictionary when present. Returns the first value
    that is not null and not empty/whitespace when converted to string.

    .PARAMETER InputObject
    The object or dictionary to inspect.

    .PARAMETER PropertyNames
    The ordered list of property names to evaluate.

    .PARAMETER DefaultValue
    The value to return when none of the requested properties contain a value.

    .EXAMPLE
    Get-FirstPropertyValue -InputObject $Object -PropertyNames @('displayName', 'name')

    Returns the first populated value found in `displayName` or `name`.

    .INPUTS
    System.Object

    .OUTPUTS
    System.Object
    #>

    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$PropertyNames,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$DefaultValue = $null
    )

    process {
        if ($null -eq $InputObject) {
            return $DefaultValue
        }

        $additionalProperties = $InputObject.PSObject.Properties['AdditionalProperties']
        $additionalPropertiesValue = $null
        if ($null -ne $additionalProperties -and $additionalProperties.Value -is [System.Collections.IDictionary]) {
            $additionalPropertiesValue = $additionalProperties.Value
        }

        foreach ($propertyName in $PropertyNames) {
            if ($InputObject -is [System.Collections.IDictionary] -and $InputObject.Contains($propertyName)) {
                $dictionaryValue = $InputObject[$propertyName]
                if ($null -ne $dictionaryValue -and -not [string]::IsNullOrWhiteSpace([string]$dictionaryValue)) {
                    return $dictionaryValue
                }
            }

            $property = $InputObject.PSObject.Properties[$propertyName]
            if ($null -ne $property) {
                $value = $property.Value
                if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
                    return $value
                }
            }

            if ($null -ne $additionalPropertiesValue -and $additionalPropertiesValue.Contains($propertyName)) {
                $apValue = $additionalPropertiesValue[$propertyName]
                if ($null -ne $apValue -and -not [string]::IsNullOrWhiteSpace([string]$apValue)) {
                    return $apValue
                }
            }
        }

        return $DefaultValue
    }
}

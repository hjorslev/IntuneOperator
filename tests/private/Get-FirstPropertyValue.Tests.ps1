BeforeAll {
    # Import the module functions
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $PrivateFunctionsPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\private'

    # Dot-source the function we're testing
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Get-FirstPropertyValue.ps1')
}

Describe 'Get-FirstPropertyValue' {
    It 'Should return the first populated direct property value' {
        # Arrange
        $inputObject = [PSCustomObject]@{
            displayName = ''
            name        = 'Device remediation'
        }

        # Act
        $result = Get-FirstPropertyValue -InputObject $inputObject -PropertyNames @('displayName', 'name')

        # Assert
        $result | Should -Be 'Device remediation'
    }

    It 'Should return a dictionary value when present' {
        # Arrange
        $inputObject = @{
            noIssueDetectedDeviceCount = 12
        }

        # Act
        $result = Get-FirstPropertyValue -InputObject $inputObject -PropertyNames @('noIssueDetectedDeviceCount')

        # Assert
        $result | Should -Be 12
    }

    It 'Should resolve values from AdditionalProperties' {
        # Arrange
        $inputObject = [PSCustomObject]@{
            AdditionalProperties = @{
                issueDetectedDeviceCount = 5
            }
        }

        # Act
        $result = Get-FirstPropertyValue -InputObject $inputObject -PropertyNames @('issueDetectedDeviceCount')

        # Assert
        $result | Should -Be 5
    }

    It 'Should return zero when zero is a valid value' {
        # Arrange
        $inputObject = [PSCustomObject]@{
            issueRemediatedDeviceCount = 0
        }

        # Act
        $result = Get-FirstPropertyValue -InputObject $inputObject -PropertyNames @('issueRemediatedDeviceCount') -DefaultValue 99

        # Assert
        $result | Should -Be 0
    }

    It 'Should return the default value when nothing is populated' {
        # Arrange
        $inputObject = [PSCustomObject]@{
            displayName = ' '
        }

        # Act
        $result = Get-FirstPropertyValue -InputObject $inputObject -PropertyNames @('displayName', 'name') -DefaultValue 'fallback'

        # Assert
        $result | Should -Be 'fallback'
    }
}

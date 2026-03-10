# IntuneOperator

## IntuneOperator

IntuneOperator is a PowerShell module for Intune that helps managing your Endpoint fleet.

## Installation

To install the module from the PowerShell Gallery, you can use the following command:

```powershell
Install-PSResource -Name IntuneOperator
Import-Module -Name IntuneOperator
```

## Usage

Here is a list of example that are typical use cases for the module.

### Example 1: Greet an entity

As for March 2026 there is one cmdlet: `Get-IntuneDeviceLogin`

```powershell
Get-IntuneDeviceLogin -DeviceName PC-001
```

```
DeviceName        : PC-001
UserPrincipalName : john.doe@contoso.com
DeviceId          : c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a
UserId            : a5b6c7d8-e9f0-1a2b-3c4d-5e6f7a8b9c0d
LastLogonDateTime : 3/9/2026 8:14:00 AM

DeviceName        : PC-001
UserPrincipalName : jane.smith@contoso.com
DeviceId          : c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a
UserId            : b1c2d3e4-f5a6-7b8c-9d0e-1f2a3b4c5d6e
LastLogonDateTime : 3/7/2026 2:45:00 PM
```

```powershell
Get-IntuneDeviceLogin -UserPrincipalName john.doe@contoso.com
```

```
DeviceName        : PC-001
UserPrincipalName : john.doe@contoso.com
DeviceId          : c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a
UserId            : a5b6c7d8-e9f0-1a2b-3c4d-5e6f7a8b9c0d
LastLogonDateTime : 3/9/2026 8:14:00 AM

DeviceName        : PC-042
UserPrincipalName : john.doe@contoso.com
DeviceId          : f7e6d5c4-b3a2-1f0e-9d8c-7b6a5f4e3d2c
UserId            : a5b6c7d8-e9f0-1a2b-3c4d-5e6f7a8b9c0d
LastLogonDateTime : 3/5/2026 9:33:00 AM
```

## Acknowledgements

  - [Process-Module](https://github.com/PSModule/Process-PSModule) by [Marius Storhaug](https://github.com/MariusStorhaug). Contains the entire build pipeline. This is greatly beneficial and helps me just concentrating on building the cmdlets.
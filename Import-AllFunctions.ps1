# Dot-source all functions in IntuneOperator.
# Usage: . ./Import-AllFunctions.ps1

$publicFolders = Get-ChildItem -Path "$PSScriptRoot/src/functions/public" -Directory
$privateFolder = Join-Path $PSScriptRoot 'src/functions/private'

# Dot-source all private functions.
Get-ChildItem -Path $privateFolder -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
}

# Dot-source all public functions, including nested folders.
foreach ($folder in $publicFolders) {
    Get-ChildItem -Path $folder.FullName -Recurse -Filter '*.ps1' | ForEach-Object {
        . $_.FullName
    }
}

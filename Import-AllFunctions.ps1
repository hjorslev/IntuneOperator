# Dot-source alle funktioner i IntuneOperator
# Brug: . ./Import-AllFunctions.ps1

$publicFolders = Get-ChildItem -Path "$PSScriptRoot/src/functions/public" -Directory
$privateFolder = Join-Path $PSScriptRoot 'src/functions/private'

# Dot-source alle private funktioner
Get-ChildItem -Path $privateFolder -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
}

# Dot-source alle public funktioner (også i subfolders)
foreach ($folder in $publicFolders) {
    Get-ChildItem -Path $folder.FullName -Recurse -Filter '*.ps1' | ForEach-Object {
        . $_.FullName
    }
}

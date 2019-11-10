# Variables:


# functions:

function forestDiscovery {
    Set-CMDiscoveryMethod -ActiveDirectoryForestDiscovery -Enabled $true -EnableActiveDirectorySiteBoundaryCreation $true -EnableSubnetBoundaryCreation $true -WhatIf
}


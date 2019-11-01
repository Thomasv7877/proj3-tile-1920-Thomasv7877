# variabels:
$ADKSetupFile = "C:\Sources\ADK\adksetup.exe"
$PESetupFile = "C:\Sources\ADK_PE\adkwinpesetup.exe"
$nat_name = "NAT"
$hostonly_name = "HOSTONLY"
$ip_adr = "192.168.56.31"

$PWordPlain = "vagrant"
$Domain = "thovan.gent"
$User = "thovan\vagrant"

# functions:

function config_basics{

    Disable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_tcpip6
    Disable-NetAdapterBinding -Name "Ethernet 2" -ComponentID ms_tcpip6
    Get-NetAdapter -Name "Ethernet" | Rename-NetAdapter -NewName $nat_name
    Get-NetAdapter -Name "Ethernet 2" | Rename-NetAdapter -NewName $hostonly_name
    Disable-NetAdapter $nat_name -Confirm:$false
    New-NetRoute -InterfaceAlias $hostonly_name -DestinationPrefix "0.0.0.0/0" -NextHop $ip_adr

}

function join_domain {
    $PWord = (ConvertTo-SecureString -String $PWordPlain -AsPlainText -Force)
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
    add-computer -domainname $Domain -Credential $Credential
}

function install_adk { # werkt niet..
    Start-Process -FilePath $ADKSetupFile -ArgumentList /features OptionId.DeploymentTools OptionId.UserStateMigrationTool /norestart /quiet /ceip off -NoNewWindow -Wait
    Start-Process -FilePath $PESetupFile -ArgumentList /Features OptionId.WindowsPreinstallationEnvironment /norestart /quiet /ceip off -NoNewWindow -Wait
}

function install_adk2 { # werkt wel
    Write-Output "Installing required items from ADK"
    $Command = $ADKSetupFile
    $Parameters = "/quiet", "/features OptionId.DeploymentTools OptionId.UserStateMigrationTool"
    Start-Process -FilePath $Command -ArgumentList $Parameters -Wait

    Write-Output "Installing required items from ADK PE add-on"
    $Command = $PESetupFile
    $Parameters = "/quiet", "/Features OptionId.WindowsPreinstallationEnvironment"
    Start-Process -FilePath $Command -ArgumentList $Parameters -Wait
}


function install_webserver { # todo
    #add-windowsAdd-WindowsFeature Web-Mgmt-Tools, Web-Server
    Install-WindowsFeature -ConfigurationFilePath "C:\vagrant\provisioning\webserver_prereq.xml"
}

function install_wsus {
    # wsus folder -> C:\Sources\WSUS, conn string -> SRV-SCCM.thovan.gent
    Install-WindowsFeature -ConfigurationFilePath "C:\vagrant\provisioning\wsus_prereq.xml"
}

function install_sccm { # todo
    Start-Process setup.exe /script scriptpathandname -Wait
}



# execution:

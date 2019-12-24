# variables:
$nat_name = "NAT"
$hostonly_name = "HOSTONLY"
$password = (ConvertTo-SecureString -String "1337_admin" -AsPlainText -Force)
$hostonly_ip = "192.168.56.31"
$hostname = $env:COMPUTERNAME
$start = "192.168.56.128"
$end = "192.168.56.254"
$mask = "255.255.255.0"
$dom_name = "thovan.gent"
$netbios_name = "THOVAN"
$scope_name = "main_scope"

# functions:
function config_basics{

    Disable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_tcpip6
    Disable-NetAdapterBinding -Name "Ethernet 2" -ComponentID ms_tcpip6
    Get-NetAdapter -Name "Ethernet" | Rename-NetAdapter -NewName $nat_name
    Get-NetAdapter -Name "Ethernet 2" | Rename-NetAdapter -NewName $hostonly_name

}
    
function config_adds {
    
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    Import-Module ADDSDeployment
    Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "WinThreshold" `
    -DomainName $dom_name `
    -DomainNetbiosName $netbios_name `
    -ForestMode "WinThreshold" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$true `
    -SafeModeAdministratorPassword $password `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true
}

# uitvoering

function oproep_alle_functies {
write-host "Configureren van basic interface settings"
config_basics
write-host "successvol -> $?"
write-host "ADDS configureren"
config_adds
write-host "successvol -> $?"
}

oproep_alle_functies

# extra:
#Start-Sleep 120

# REBOOT
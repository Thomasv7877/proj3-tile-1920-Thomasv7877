# variabels:
$ADKSetupFile = "C:\Sources\ADK_NEW\adksetup.exe"
$PESetupFile = "C:\Sources\ADK_PE_NEW\adkwinpesetup.exe"
$nat_name = "NAT"
$hostonly_name = "HOSTONLY"
$ip_adr = "192.168.56.31"
$dns_ip = "192.168.56.31"

$PWordPlain = "vagrant"
$Domain = "thovan.gent"
$User = "thovan\vagrant"
$sql_user = "thovan\vagrant"
$sql_login = "thovan\administrator"

# functions:

function config_basics{

    Disable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_tcpip6
    Disable-NetAdapterBinding -Name "Ethernet 2" -ComponentID ms_tcpip6
    Get-NetAdapter -Name "Ethernet" | Rename-NetAdapter -NewName $nat_name
    Get-NetAdapter -Name "Ethernet 2" | Rename-NetAdapter -NewName $hostonly_name
    #Disable-NetAdapter $nat_name -Confirm:$false
    New-NetRoute -InterfaceAlias $hostonly_name -DestinationPrefix "0.0.0.0/0" -NextHop $ip_adr
    Set-DnsClientServerAddress -InterfaceAlias $hostonly_name -ServerAddresses ($dns_ip)

}

function join_domain {
    $PWord = (ConvertTo-SecureString -String $PWordPlain -AsPlainText -Force)
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
    add-computer -domainname $Domain -Credential $Credential
}

# REBOOT

# Execution:
function oproep_alle_functies {
config_basics
join_domain
}

oproep_alle_functies
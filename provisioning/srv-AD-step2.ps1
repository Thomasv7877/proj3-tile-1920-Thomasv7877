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

# functies:
function match_vagrant_to_administrator {
    $groups = ("schema admins","domain admins","enterprise admins","group policy creator owners")
    foreach($group in $groups){
        Add-ADGroupMember -Identity $group -Members "vagrant" -Server "srv-AD.thovan.gent"
    }
}

function dns_put_ip{
    Set-DnsClientServerAddress -InterfaceAlias $hostonly_name -ServerAddresses ($hostonly_ip)
}
    
function dns_extra_zones{ # todo: de reverse zone?
    Add-DnsServerPrimaryZone -NetworkId "192.168.56.0/24" -ReplicationScope Forest -ComputerName "srv-AD.thovan.gent"
}
    
function config_nat{

    # legacy remote access menu enabelen
    #Set-Itemproperty -path 'HKLM:\SYSTEM\ControlSet001\Services\RemoteAccess\Parameters' -Name 'ModernStackEnabled' -value 0

    # alt install: 
    install-windowsfeature remoteaccess, directaccess-vpn, routing -includemanagementtools

    #Install-WindowsFeature Routing -IncludeManagementTools
    Install-RemoteAccess -VpnType Vpn
     
    cmd.exe /c "netsh routing ip nat install"
    cmd.exe /c "netsh routing ip nat add interface $nat_name full"
    
    # onderstaande is overbodig?
    #cmd.exe /c "netsh routing ip nat add interface $nat_name"
    #cmd.exe /c "netsh routing ip nat set interface $hostonly_name mode=full"
    #cmd.exe /c "netsh routing ip nat add interface $hostonly_name"
    Set-Itemproperty -path 'HKLM:\SYSTEM\ControlSet001\Services\RemoteAccess\Parameters' -Name 'ModernStackEnabled' -value 0
}
    
function config_dhcp{

    $User = "localhost\Administrator"
    $PWord = (ConvertTo-SecureString -String "vagrant" -AsPlainText -Force)
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
    $cs = New-CimSession -Credential $credential -ComputerName localhost

    Install-WindowsFeature DHCP -IncludeManagementTools
    Add-DhcpServerInDC -DnsName "$hostname.$dom_name" -IPAddress $hostonly_ip -CimSession $cs
    Get-DhcpServerInDC # authorizatie checken
    Add-DhcpServerv4Scope -name $scope_name -StartRange $start -EndRange $end -SubnetMask $mask -State Active
    Set-DhcpServerv4OptionValue -ComputerName "srv-AD.thovan.gent" -DnsServer 192.168.56.31 -DnsDomain "thovan.gent" -Router 192.168.56.31

    # Overbodig:
    #Add-DhcpServerv4ExclusionRange -ScopeID 10.0.0.0 -StartRange 10.0.0.1 -EndRange 10.0.0.15
}

function create_config_container {

    $DomainDN = (Get-ADDomain).DistinguishedName
    $SystemDN = "CN=System," + $DomainDN
    New-ADObject -Type Container -name "System Management" -Path "$SystemDN" -Passthru

}

function extend_ad_schema {
    $PWordPlain = "vagrant"
    $User = "thovan\Administrator"
    $PWord = (ConvertTo-SecureString -String $PWordPlain -AsPlainText -Force)
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord

    Start-Process -FilePath C:\Sources\SC_Configmgr_SCEP_1902\SMSSETUP\BIN\X64\extadsch.exe -Wait -Credential $credential
}

function config_firewall {
    $gpo1 = "Client Push Policy Settings"
    $gpo2 = "SQL Ports for SCCM"

    new-gpo -name $gpo1
    import-GPO -Domain $dom_name -BackupId 6EFCAB8F-75E9-48A6-8EE5-FFF481566812 -Path C:\vagrant\provisioning -TargetName $gpo1
    new-gpo -name $gpo2
    import-GPO -Domain $dom_name -BackupId 0BA78A36-741F-4573-AAE4-1B2930AA3292 -Path C:\vagrant\provisioning -TargetName $gpo2
}



# oproep:
function oproep_alle_functies {
match_vagrant_to_administrator
dns_put_ip
dns_extra_zones
config_nat
config_dhcp
create_config_container
extend_ad_schema
config_firewall
}

oproep_alle_functies
# variables:
$nat_name = "NAT"
$hostonly_name = "HOSTONLY"
$password = ConvertTo-SecureString -String "1337_admin" -AsPlainText -Force
$hostonly_ip = "192.168.56.31"
$hostname = $env:COMPUTERNAME
$start = 192.168.56.1
$end = 192.168.56.30
$mask = 255.255.255.0
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
    # Add-WindowsFeature -name rsat-role-tools
    Import-Module ADDSDeployment
    Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "WinThreshold" `
    -DomainName $dom_name `
    -DomainNetbiosName $netbios_name `
    -SafeModeAdministratorPassword $password ` # gewoon string indien error
    -ForestMode "WinThreshold" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$false `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true
}
    
function dns_put_ip{
    Set-DnsClientServerAddress -InterfaceAlias $hostonly_name -ServerAddresses ($hostonly_ip)
}
    
function dns_extra_zones{
    
}
    
function config_nat{

    Install-WindowsFeature Routing -IncludeManagementTools
    Install-RemoteAccess -VpnType Vpn
     
    cmd.exe /c "netsh routing ip nat install"
    cmd.exe /c "netsh routing ip nat add interface $nat_name"
    cmd.exe /c "netsh routing ip nat set interface $hostonly_name mode=full"
    cmd.exe /c "netsh routing ip nat add interface $hostonly_name"

}
    
function config_dhcp{
    Install-WindowsFeature DHCP -IncludeManagementTools
    Add-DhcpServerInDC -DnsName "$hostname.$dom_name" -IPAddress $hostonly_ip # authorizeren in domein
    Get-DhcpServerInDC # authorizatie checken
    Add-DhcpServerv4Scope -name $scope_name -StartRange $start -EndRange $end -SubnetMask $mask -State Active
    # Add-DhcpServerv4ExclusionRange -ScopeID 10.0.0.0 -StartRange 10.0.0.1 -EndRange 10.0.0.15
}

# operations:
#Write-Output "wahtwoord = $password, hostname = $hostname"
#Write-Output "$hostname.$dom_name"

#config_basics
config_adds   

#Disable-NetAdapterBinding -Name "NAT" -ComponentID ms_tcpip6
#Disable-NetAdapterBinding -Name "HOSTONLY" -ComponentID ms_tcpip6
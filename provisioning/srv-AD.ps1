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
    
function dns_put_ip{
    Set-DnsClientServerAddress -InterfaceAlias $hostonly_name -ServerAddresses ($hostonly_ip)
}
    
function dns_extra_zones{ # todo: de reverse zone?
    
}
    
function config_nat{

    # legacy remote access menu enabelen
    #Set-Itemproperty -path 'HKLM:\SYSTEM\ControlSet001\Services\RemoteAccess\Parameters' -Name 'ModernStackEnabled' -value 0

    Install-WindowsFeature Routing -IncludeManagementTools
    Install-RemoteAccess -VpnType Vpn
     
    cmd.exe /c "netsh routing ip nat install"
    Set-Itemproperty -path 'HKLM:\SYSTEM\ControlSet001\Services\RemoteAccess\Parameters' -Name 'ModernStackEnabled' -value 0
    # onderstaande is overbodig
    cmd.exe /c "netsh routing ip nat add interface $nat_name"
    cmd.exe /c "netsh routing ip nat set interface $hostonly_name mode=full"
    cmd.exe /c "netsh routing ip nat add interface $hostonly_name"

}
    
function config_dhcp{

    $User = "localhost\Administrator"
    $PWord = (ConvertTo-SecureString -Strindns_pu   g "vagrant" -AsPlainText -Force)
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
    $cs = New-CimSession -Credential $credential -ComputerName localhost

    Install-WindowsFeature DHCP -IncludeManagementTools
    Add-DhcpServerInDC -DnsName "$hostname.$dom_name" -IPAddress $hostonly_ip -CimSession $cs
    Get-DhcpServerInDC # authorizatie checken
    Add-DhcpServerv4Scope -name $scope_name -StartRange $start -EndRange $end -SubnetMask $mask -State Active
    # Add-DhcpServerv4ExclusionRange -ScopeID 10.0.0.0 -StartRange 10.0.0.1 -EndRange 10.0.0.15
}

function create_config_container {

    $DomainDN = (Get-ADDomain).DistinguishedName
    $ThisSiteSystem = Get-ADComputer $env:ComputerName 
    $SystemDN = "CN=System," + $DomainDN
    $Container = New-ADObject -Type Container -name "System Management" -Path "$SystemDN" -Passthru
 
    $ACL = Get-ACL -Path AD:\$Container

    $SID = [System.Security.Principal.SecurityIdentifier] $ThisSiteSystem.SID

    $adRights = [System.DirectoryServices.ActiveDirectoryRights] "GenericAll"
    $type = [System.Security.AccessControl.AccessControlType] "Allow"
    $inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
    $ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
                                     $SID,$adRights,$type,$inheritanceType

    $ACL.AddAccessRule($ACE)

    Set-ACL -AclObject $ACL -Path "AD:$Container"
}

function create_config_container { # effect??

    $DomainDN = (Get-ADDomain).DistinguishedName
    $ThisSiteSystem = Get-ADComputer $env:ComputerName 
    $SystemDN = "CN=System," + $DomainDN
    $Container = New-ADObject -Type Container -name "System Management" -Path "$SystemDN" -Passthru
 
    $ACL = Get-ACL -Path AD:\$Container

    $SID = [System.Security.Principal.SecurityIdentifier] $ThisSiteSystem.SID

    $adRights = [System.DirectoryServices.ActiveDirectoryRights] "GenericAll"
    $type = [System.Security.AccessControl.AccessControlType] "Allow"
    $inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
    $ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
                                     $SID,$adRights,$type,$inheritanceType

    $ACL.AddAccessRule($ACE)

    Set-ACL -AclObject $ACL -Path "AD:$Container"
}

function extend_ad_schema {
    $PWordPlain = "vagrant"
    $User = "thovan\Administrator"
    $PWord = (ConvertTo-SecureString -String $PWordPlain -AsPlainText -Force)
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord

    Start-Process -FilePath C:\Sources\SC_Configmgr_SCEP_1902\SMSSETUP\BIN\X64\extadsch.exe -Wait -Credential $credential
}

# operations:
#Write-Output "wahtwoord = $password, hostname = $hostname"
#Write-Output "$hostname.$dom_name"

#config_basicsecho 
#config_adds   

#Disable-NetAdapterBinding -Name "NAT" -ComponentID ms_tcpip6
#Disable-NetAdapterBinding -Name "HOSTONLY" -ComponentID ms_tcpip6
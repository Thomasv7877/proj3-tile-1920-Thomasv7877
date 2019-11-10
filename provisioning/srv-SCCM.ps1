# variabels:
$ADKSetupFile = "C:\Sources\ADK\adksetup.exe"
$PESetupFile = "C:\Sources\ADK_PE\adkwinpesetup.exe"
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
    Disable-NetAdapter $nat_name -Confirm:$false
    New-NetRoute -InterfaceAlias $hostonly_name -DestinationPrefix "0.0.0.0/0" -NextHop $ip_adr
    Set-DnsClientServerAddress -InterfaceAlias $hostonly_name -ServerAddresses ($dns_ip)

}

function join_domain {
    $PWord = (ConvertTo-SecureString -String $PWordPlain -AsPlainText -Force)
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
    add-computer -domainname $Domain -Credential $Credential
}

# REBOOT

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


function install_webserver {
    #add-windowsAdd-WindowsFeature Web-Mgmt-Tools, Web-Server
    Install-WindowsFeature -ConfigurationFilePath "C:\vagrant\provisioning\webserver_prereq.xml"
}

function install_wsus {
    # wsus folder -> (C:\Sources\WSUS) C:\WSUS, conn string -> SRV-SCCM.thovan.gent
    New-Item -Path C: -Name WSUS -ItemType Directory
    #Install-WindowsFeature -ConfigurationFilePath "C:\vagrant\provisioning\wsus_prereq.xml"
    Install-WindowsFeature -Name UpdateServices-Services,UpdateServices-DB -IncludeManagementTools
    Start-Process -FilePath "C:\Program Files\Update Services\Tools\WsusUtil.exe" -ArgumentList "postinstall CONTENT_DIR=C:\WSUS SQL_INSTANCE_NAME=srv-SCCM.thovan.gent" -wait -NoNewWindow
}

function change_sql_logon {
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | out-null

    $SMOWmiserver = New-Object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer') "srv-SCCM" 
    $ChangeService=$SMOWmiserver.Services | where {$_.name -eq "MSSQLSERVER"} 
    $ChangeService.SetServiceAccount($sql_login, $PWordPlain)

    Restart-Service -Force MSSQLSERVER
}

function extend_ad_schema { # alleen op srv-AD?
    $PWordPlain = "vagrant"
    $User = "thovan\Administrator"
    $PWord = (ConvertTo-SecureString -String $PWordPlain -AsPlainText -Force)
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord

    Start-Process -FilePath C:\Sources\SC_Configmgr_SCEP_1902\SMSSETUP\BIN\X64\extadsch.exe -Wait -Credential $credential
}

function create_sql_user {
    # niet nodig:
    #Install-Module -name sqlserver -Force

$script_sp = @"
    USE [master]
    GO

    CREATE LOGIN [$sql_user] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]
    GO

    ALTER SERVER ROLE [sysadmin] ADD MEMBER [$sql_user]
    GO
"@

invoke-sqlcmd -query $script_sp

}

function correct_sql_name {
    $script_sp = @"
    EXEC sp_dropserver 'WINGUSZ-U62L3FP';
    GO
    EXEC sp_addserver 'srv-SCCM', 'local';
    GO
"@
invoke-sqlcmd -query $script_sp
}

function install_sccm { # testen
    Start-Process "C:\Sources\SC_Configmgr_SCEP_1902\SMSSETUP\BIN\X64\setup.exe" /script "C:\vagrant\provisioning\setup.ini" -Wait
}

function test {
    echo "test functie oproep"
    whoami
}



# execution:

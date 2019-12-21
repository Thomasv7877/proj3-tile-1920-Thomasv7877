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
function remote_delegate_control { # test
    Set-ExecutionPolicy Unrestricted -force

    $User = "thovan\vagrant"
    $PWordPlain = "vagrant"
    $PWord = (ConvertTo-SecureString -String $PWordPlain -AsPlainText -Force)
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
    $session = New-PSSession -ComputerName "srv-AD" -Credential $Credential

    Invoke-Command $session -Scriptblock { 
        $ThisSiteSystem = Get-ADComputer "srv-SCCM"
        $Container = Get-ADObject -Filter 'name -eq "System Management"'
    
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

}

function install_adk { # werkt niet..
    Start-Process -FilePath $ADKSetupFile -ArgumentList "/features OptionId.DeploymentTools OptionId.UserStateMigrationTool /norestart /quiet /ceip off" -NoNewWindow -Wait
    Start-Process -FilePath $PESetupFile -ArgumentList "/Features OptionId.WindowsPreinstallationEnvironment /norestart /quiet /ceip off" -NoNewWindow -Wait
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


function install_webserver { # bits toevoegen aan eerste xml ipv twee..
    #add-windowsAdd-WindowsFeature Web-Mgmt-Tools, Web-Server
    #Install-WindowsFeature -ConfigurationFilePath "C:\vagrant\provisioning\webserver_prereq.xml"
    #Install-WindowsFeature -ConfigurationFilePath "C:\vagrant\provisioning\webserver_prereq_bits.xml"
    Install-WindowsFeature -ConfigurationFilePath "C:\vagrant\provisioning\webserver_prereq_full.xml"
}

function install_wsus {
    # wsus folder -> (C:\Sources\WSUS) C:\WSUS, conn string -> SRV-SCCM.thovan.gent
    New-Item -Path C:\ -Name WSUS -ItemType Directory
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
    $Share =[wmiClass]"Win32_share"
    $Share.create("C:\Sources","Sources",0)
    $Share.create("C:\Vagrant","Vagrant",0)

    Start-Process "C:\Sources\SC_Configmgr_SCEP_1902\SMSSETUP\BIN\X64\setup.exe" -argumentlist  "/script \\srv-SCCM\Vagrant\provisioning\setup.ini" -Wait
}

# REBOOT

function test {
    echo "test functie oproep"
    whoami
}

# execution:
function oproep_alle_functies {
remote_delegate_control
install_adk2
install_webserver
install_wsus
change_sql_logon
extend_ad_schema
create_sql_user
correct_sql_name
install_sccm
}

oproep_alle_functies
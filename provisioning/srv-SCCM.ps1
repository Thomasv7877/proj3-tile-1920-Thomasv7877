# variabels:
$ADKSetupFile = # todo
$PESetupFile = # todo

# functions:
install_adk {
    Start-Process -FilePath $ADKSetupFile -ArgumentList /Features OptionId.DeploymentTools  OptionId.UserStateMigrationTool /norestart /quiet /ceip off -NoNewWindow -Wait
    Start-Process -FilePath $PESetupFile -ArgumentList /Features OptionId.WindowsPreinstallationEnvironment /norestart /quiet /ceip off -NoNewWindow -Wait
}

create_config_container {

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

extend_ad_schema { # todo: pad aanpassen
    Start-Process -FilePath C:\Sources\SC2012_SP2_Configmgr_SCEP\SMSSETUP\BIN\X64\extadsch.exe -Wait
}

install_webserver { # todo
    Add-WindowsFeature Web-Mgmt-Tools, Web-Server
}

install_sccm { # todo
    Start-Process setup.exe /script scriptpathandname -Wait
}



# execution:

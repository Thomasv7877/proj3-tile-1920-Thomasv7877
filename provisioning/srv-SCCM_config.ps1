# Variables:


# functions:

function prepare_SCCM_cmdlet {
    Set-Location 'C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin'
    Import-Module .\ConfigurationManager.psd1
    Set-Location P01:
}

function forestDiscovery { # ook manueel laten discoveren?
    Set-CMDiscoveryMethod -ActiveDirectoryForestDiscovery -Enabled $true -EnableActiveDirectorySiteBoundaryCreation $true -EnableSubnetBoundaryCreation $true
}

function boundaries {
    $site = Get-CMSiteSystemServer -SiteSystemServerName "srv-SCCM.thovan.gent" -SiteCode "P01"
    $bgroup = New-CMBoundaryGroup -Name "Boundary Group" -DefaultSiteCode "P01" -AddSiteSystemServer $site
    $group = New-CMBoundary -BoundaryType ADSite -Value "Default-First-Site-Name"
    Add-CMBoundaryToGroup -InputObject $group -BoundaryGroupInputObject $bgroup
    #Set-CMBoundaryGroup -InputObject $bgroup
}

function site_roles { # logs in orde? zie sccm.pdf
    Add-CMApplicationCatalogWebServicePoint -PortNumber 80 -SiteCode "P01" -SiteSystemServerName "srv-SCCM.thovan.gent"
    Add-CMApplicationCatalogWebsitePoint -Color blue -SiteCode "P01" -SiteSystemServerName "srv-SCCM.thovan.gent" -OrganizationName "thovan.gent organization" -NetBiosName "SCCM" -CommunicationType Http -ApplicationWebServicePointServerName "srv-SCCM.thovan.gent"
    Add-CMFallbackStatusPoint -SiteCode "P01" -SiteSystemServerName "srv-SCCM.thovan.gent" -StateMessageNum 10000 -ThrottleInterval 60
}

function dist_point_pxe_settings {
    $DP = Get-CMDistributionPoint -SiteSystemServerName "srv-SCCM.thovan.gent"
    Set-CMDistributionPoint -InputObject $DP -EnablePxe $true -AllowPxeResponse $true -EnableUnknownComputerSupport $true
}

function boot_images_settings {
    $boot_x64 = Get-CMBootImage -Name "Boot image (x64)"
    Set-CMBootImage -InputObject $boot_x64 -EnableCommandSupport $true -DeployFromPxeDistributionPoint $true
    $boot_x86 = Get-CMBootImage -Name "Boot image (x86)"
    Set-CMBootImage -InputObject $boot_x86 -EnableCommandSupport $true -DeployFromPxeDistributionPoint $true

    Start-CMContentDistribution -BootImageName ("Boot image (x64)","Boot image (x86)") -DistributionPointName "srv-SCCM.thovan.gent"
}

function client_install_settings {
    $Secure = ConvertTo-SecureString -String "vagrant" -AsPlainText -Force
    New-CMAccount -Name "thovan\vagrant" -Password $Secure -SiteCode "P01" # alt -> thovan\administrator?
    Set-CMClientPushInstallation -SiteCode "P01" -EnableAutomaticClientPushInstallation $True -InstallClientToDomainController $true -chosenaccount "thovan\vagrant"
    # ook account toevoegen/specifieeren? -> -AddAccount/chosenaccount "thovan\administrator"
}

function import_os {
    $Share =[wmiClass]"Win32_share"
    $Share.create("C:\Sources","Sources",0)
    New-CMOperatingSystemImage -Name "Windows 10 1904" -Path "\\srv-SCCM\Sources\captured\win10_1904.wim"
    Start-CMContentDistribution -OperatingSystemImageName "Windows 10" -DistributionPointName "srv-SCCM.thovan.gent"
}

function prep_deployment {
    $coll = New-CMDeviceCollection -Name "Windows 10" -LimitingCollectionName "All Systems"
    Import-CMComputerInformation -CollectionName "Windows 10" -ComputerName "Client1" -MacAddress "08:00:27:8F:43:60" 
    # geen '_' in computername! bovenstaande commando deployed niet (direct) naar gekozen collection?

    $passw = (ConvertTo-SecureString -String "vagrant" -AsPlainText -Force)
    $taskseq = New-CMTaskSequence -InstallOperatingSystemImage -Name "deploy os" -BootImagePackageId P0100003 -OperatingSystemImagePackageId P0100006 -OperatingSystemImageIndex 1 -JoinDomain DomainType -DomainName "thovan.gent" -DomainOrganizationUnit "LDAP://CN=Computers,DC=thovan,DC=gent" -DomainAccount "thovan\vagrant" -DomainPassword $passw -ApplyAll $true -Description "Windows 10 installeren op de client" -ConfigureBitLocker $false
    # opm: -ApplicationName ("name1","name2") om de apps later toe te voegen -LocalAdminPassword $passw -PartitionAndFormatTarget $true

    $StepVar1 = New-CMTSStepConditionVariable -OperatorType NotExists -ConditionVariableName _SMSTSClientCache
    $StepVar2 = New-CMTSStepConditionVariable -OperatorType NotEquals -ConditionVariableName _SMSTSMediaType -ConditionVariableValue OEMMedia
    $StepVar3 = New-CMTSStepConditionVariable -OperatorType NotEquals -ConditionVariableName _OSDMigrateUseHardlinks -ConditionVariableValue true
    $StepVar4 = New-CMTSStepConditionVariable -OperatorType NotEquals -ConditionVariableName _SMSTSBootUEFI -ConditionVariableValue true

    $BIOSPartitionScheme = @(
        #$(New-CMTaskSequencePartitionSetting -PartitionPrimary -Name 'System Reserved' -Size 750 -SizeUnit MB -EnableDriveLetterAssignment $false -IsBootPartition $true),
        $(New-CMTaskSequencePartitionSetting -PartitionPrimary -Name 'Windows' -Size 100 -SizeUnit Percent)
        #$(New-CMTaskSequencePartitionSetting -PartitionRecovery -Name 'Recovery' -Size 100 -SizeUnit Percent)
    ) 
    $TSStepBIOSPartition = New-CMTaskSequenceStepPartitionDisk -Name 'Partition Disk 0 - BIOS' -DiskType Mbr -DiskNumber 0 -PartitionSetting $BIOSPartitionScheme -Condition ($StepVar1,$StepVar2,$StepVar3,$StepVar4)
        
    $UEFIPartitionScheme = @(
        $(New-CMTaskSequencePartitionSetting -PartitionEfi -Size 1 -SizeUnit GB),
        $(New-CMTaskSequencePartitionSetting -PartitionMsr -Size 128 -SizeUnit MB),
        $(New-CMTaskSequencePartitionSetting -PartitionPrimary -Name 'Windows' -Size 100 -SizeUnit Percent)
        #$(New-CMTaskSequencePartitionSetting -PartitionRecovery -Name 'Recovery' -Size 100 -SizeUnit Percent)
    )     
    $TSStepUEFIPartition = New-CMTaskSequenceStepPartitionDisk -Name 'Partition Disk 0 - UEFI' -DiskType Gpt -DiskNumber 0 -PartitionSetting $UEFIPartitionScheme -IsBootDisk $true -Condition ($StepVar1,$StepVar2,$StepVar3,$StepVar4)
    Set-CMTaskSequenceGroup -InputObject $taskseq -StepName "Install Operating System" -AddStep ($TSStepUEFIPartition, $TSStepBIOSPartition) -InsertStepStartIndex 1
         
    New-CMTaskSequenceDeployment -InputObject $taskseq -Collection $coll -Availability MediaAndPxe -AllowFallback $true
}

function create_network_access_account {
    $NAA = "thovan\vagrant"
    #$pwd = (ConvertTo-SecureString -String "V@grant" -AsPlainText -Force)
    #New-CMAccount -Name $NAA -Password $pwd -Sitecode "P01"
    $SiteCode = Get-PSDrive -PSProvider CMSITE

    $component = gwmi -class SMS_SCI_ClientComp -Namespace "root\sms\site_$($SiteCode.Name)"  | Where-Object {$_.ItemName -eq "Software Distribution"}
    $props = $component.PropLists
    $prop = $props | where {$_.PropertyListName -eq "Network Access User Names"}

	# Create a new instance of the Embedded Propertylist
    $new = [WmiClass] "root\sms\site_$($SiteCode.name):SMS_EmbeddedPropertyList"
    $embeddedproperylist = $new.CreateInstance()

    $embeddedproperylist.PropertyListName = "Network Access User Names"
    $prop.Values = $NAA
    $component.PropLists = $props
    $component.Put() | Out-Null
}

function create_applications {
    # Adobe Reader DC:
    $adreader = new-cmapplication -name "Adobe Acrobat Reader DC" -publisher "Adobe" -softwareversion "2018.011.20036"
    $adreader_detection = New-CMDetectionClauseWindowsInstaller -ProductCode "{AC76BA86-7AD7-1033-7B44-AC0F074E4100}" -Existence add-CMscriptDeploymentType -InputObject $adreader -DeploymentTypeName "Adobe Acrobat Reader DC deployment" -ContentLocation "\\srv-SCCM\Sources\applicaties\adobe reader dc\2018.011.20036\" -InstallCommand "setup.exe" -UninstallCommand "msiexec /x {AC76BA86-7AD7-1033-7B44-AC0F074E4100} /q" -AddDetectionClause $adreader_detection
    Start-CMContentDistribution -InputObject $adreader -DistributionPointName "srv-SCCM.thovan.gent"
    # 7-zip:
}
write-host "uivoering test script"
function match_vagrant_to_administrator {
    $groups = ("schema admins","domain admins","enterprise admins","group policy creator owners")
    foreach($group in $groups){
        Add-ADGroupMember -Identity $group -Members "vagrant" -Server "srv-AD.thovan.gent"
    }
}

function extend_ad_schema {
    $PWordPlain = "vagrant"
    $User = "thovan\vagrant"
    $PWord = (ConvertTo-SecureString -String $PWordPlain -AsPlainText -Force)
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
    $workingdir = $(get-location)
    write-host "We zitten nu in $workindir"
    Start-Process -FilePath C:\Sources\SC_Configmgr_SCEP_1902\SMSSETUP\BIN\X64\extadsch.exe -Wait -NoNewWindow -Verbose
}

function dns_extra_zones{ # todo: de reverse zone?
    $User = "localhost\Administrator"
    $PWord = (ConvertTo-SecureString -String "vagrant" -AsPlainText -Force)
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
    $cs = New-CimSession -Credential $credential -ComputerName localhost

    Add-DnsServerPrimaryZone -NetworkId "192.168.56.0/24" -ReplicationScope Forest -ComputerName localhost
}

extend_ad_schema
#dns_extra_zones


#match_vagrant_to_administrator
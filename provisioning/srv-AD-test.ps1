write-host "uivoering test script"
function match_vagrant_to_administrator {
    $groups = ("schema admins","domain admins","enterprise admins","group policy creator owners")
    foreach($group in $groups){
        Add-ADGroupMember -Identity $group -Members "vagrant" -Server "srv-AD.thovan.gent"
    }
}
    
function dns_extra_zones{ # todo: de reverse zone?
    Add-DnsServerPrimaryZone -NetworkId "192.168.56.0/24" -ReplicationScope Forest -ComputerName "srv-AD.thovan.gent"
}

match_vagrant_to_administrator
dns_extra_zones
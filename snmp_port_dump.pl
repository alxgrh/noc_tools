#!/usr/bin/perl

use Net::SNMP;
use Getopt::Std;


if ($#ARGV < 0) {
     usage();
}

# SNMP options
$version = "2c";
$timeout = 2;

$ifnumber = 0;

$oid_sysdescr           = ".1.3.6.1.2.1.1.1.0";
$oid_sysobjoid			= ".1.3.6.1.2.1.1.2";
$oid_ifnumber           = ".1.3.6.1.2.1.2.1.0";         # number of interfaces on device
#$oid_ifdescr            = ".1.3.6.1.2.1.2.2.1.2.";
$oid_ifdescr            = ".1.3.6.1.2.1.31.1.1.1.1.";
$oid_ifalias            = ".1.3.6.1.2.1.31.1.1.1.18.";
$oid_iftype             = ".1.3.6.1.2.1.2.2.1.3.";
$oid_ifadminstatus      = ".1.3.6.1.2.1.2.2.1.7.";
$oid_ifoperstatus       = ".1.3.6.1.2.1.2.2.1.8.";
$oid_ifindex            = ".1.3.6.1.2.1.2.2.1.1";

# Cisco OIDS

$oid_ifswmode			= ".1.3.6.1.4.1.9.9.46.1.6.1.1.14."; #CISCO-VTP-MIB::vlanTrunkPortDynamicStatus
$oid_ifswmodeconf		= ".1.3.6.1.4.1.9.9.46.1.6.1.1.13."; #CISCO-VTP-MIB::vlanTrunkPortDynamicState
$oid_vlanid				= ".1.3.6.1.4.1.9.9.68.1.2.2.1.2."; #CISCO-VLAN-MEMBERSHIP-MIB::vmVlan
$oid_trunkvlans			= ".1.3.6.1.4.1.9.9.46.1.6.1.1.4."; # vlids 0-1023 CISCO-VTP-MIB::vlanTrunkPortVlansEnabled
$oid_trunkvlans2k		= ".1.3.6.1.4.1.9.9.46.1.6.1.1.17."; # vlids 1024-2047
$oid_trunkvlans3k		= ".1.3.6.1.4.1.9.9.46.1.6.1.1.18."; # vlids 2048-3071
$oid_trunkvlans4k		= ".1.3.6.1.4.1.9.9.46.1.6.1.1.19."; # vlids 3072-4095

$ifdescr                = "n/a";
$ifalias                = "n/a";
$iftype                 = "n/a";
$ifadminstatus          = "n/a";
$ifoperstatus           = "n/a";
$sysOID					= "";
$ifindex				= 0;
$ifswmode               = "n/a";

my @vlans;
$community = "public";          # Default community string




getopts("c:h");
if ($opt_h){
    usage();
    exit(0);
}
if ($opt_c){
    $community = $opt_c;
}




dump_switch_info ($ARGV[0] , $community);

sub dump_switch_info{
	$hostname="$_[0]";
	$community="$_[1]";
#	print "Hostname: $hostname \n";

############Create SNMP session#########################
	($s, $e) = Net::SNMP->session(
	   -community    =>  $community,
	   -hostname     =>  $hostname,
	   -version      =>  $version,
	   -timeout      =>  $timeout,
	);
	if (!defined($s)){ print "Can't create SNMP session\n"; exit 1;}
###########Determining number of interfaces#############	
	if (!defined($s->get_request($oid_ifnumber))) {
        if (!defined($s->get_request($oid_sysdescr))) {
            print "SNMP agent not responding\n";
            exit 1;
        }
        else {
        	
            print "SNMP OID does not exist\n";
            exit 1;
        }
    }
    else {
        $ifnumber = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]}; 
        if ($ifnumber == 0){
                return 1;
        }
    }

##########Determining SysObjectID#########################    
    if (!defined($s->get_next_request($oid_sysobjoid))){
    	print "Cannot define SysObjectID\n";
    }
    else {
    	$sysOID = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
	$sysobj=`snmptranslate -Ta -m CISCO-PRODUCTS-MIB $sysOID | cut -d : -f 3`;
	chomp $sysobj;
	if ($sysobj eq "enterprises.3955.6.1.208.2" ){
		print "SysOID: $sysobj - SRW208G\n\n";
	} elsif ($sysobj eq "enterprises.3955.6.1.208.3" ){
                print "SysOID: $sysobj - SRW208L\n\n";
        } elsif ($sysobj eq "enterprises.3955.6.9.208.2" ){
                print "SysOID: $sysobj - SPS208G\n\n";
        } else { 
    		print "SysOID: $sysobj\n\n";
	}
    }
    
    print "Interfaces table:\n";
    print "Interface\t  AdminStatus\tOperStatus\tVlan\tDescription\n";
    print "------------------------------------------------------------------------------------\n";
    
##########Get Interfaces Info#########################    
	$y=1;
	###### Startup ifindex #######
	if (!defined($s->get_next_request($oid_ifindex))){
    	print "Cannot define ifindex\n";
    }
    else {
    	$ifindex = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]}; 
#    	print "Startup ifindex: $ifindex\n";
    }
    
    #########################
    ######## MAIN LOOP ######
    #########################
    while($y <= $ifnumber){
		
#		print "ifindex: $ifindex\n";
		$outputline="";

		###### ifDescription #####
		if (!defined($s->get_request($oid_ifdescr.$ifindex))){
    		print "Cannot define ifDescription\n";
    	}
    	else {
    		$ifdescr = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
#    		print "ifDescription: $ifdescr\n";
			$outputline .= "$ifdescr \t\t"
    	}
    
	    ###### iftype ########
    	if (!defined($s->get_request($oid_iftype.$ifindex))){
	    	print "Cannot define iftype\n";
    	}
    	else {
    		$iftype = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
#    		print "iftype: $iftype\n";
    	}
	    
	    ###### ifadminstatus ########
    	if (!defined($s->get_request($oid_ifadminstatus .$ifindex))){
	    	print "Cannot define ifadminstatus\n";
	    }
    	else {
    		$ifadminstatus = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
#    		print "ifadminstatus: $ifadminstatus\n";
			if ($ifadminstatus eq "1"){
				$outputline .= "up(1)\t"
			}
			else{
				if($ifadminstatus eq "2"){
					$outputline .= "down(2)\t"
				}
			}
    	}
    
	    ###### ifoperstatus ########
	    if (!defined($s->get_request($oid_ifoperstatus.$ifindex))){
	    	print "Cannot define if\n";
	    }
	    else {
	    	$ifoperstatus = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
#    		print "ifoperstatus: $ifoperstatus\n";
			if ($ifoperstatus eq "1"){
				$outputline .= "up(1)\t\t"
			}
			else{
				if($ifoperstatus eq "2"){
					$outputline .= "down(2)\t\t"
				}
			}
    	}
	    
	    ###### ifswmode ########
	    $ifswmode = "n/a";
	    if ($sysOID =~ m/.1.3.6.1.4.1.9/ && $ifadminstatus == 1 && $iftype == 6 && $ifoperstatus == 1){
	    	if (!defined($s->get_request($oid_ifswmode.$ifindex))){
		    	print "Cannot determine interface switchport mode\n";
			}
		else {
    			$ifswmode = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
#    			print "ifswmode: $ifswmode\n";
		}
    	
    	}
    	else{
    		if($iftype == 6){
    			if (!defined($s->get_request($oid_ifswmodeconf.$ifindex))){
		    		print "Cannot determine interface switchport mode\n";
			}
			else {
    				$ifswmode = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
#    				print "ifswmodeconf: $ifswmode\n";
			}
    		}
    	}
    	
    	 
	    ###### non-trunking port vlan  ######
	    if ($ifswmode eq "2"){
	    	if (!defined($s->get_request($oid_vlanid.$ifindex))){
	    		print "Cannot determine interface vlan\n";
			}
		else {
    			$vlan = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
#    			print "Vlan: $vlan\n";
				$outputline.="$vlan\t";
		}    	
    	}
    	###### trunk port vlans #######
    	else{
    		if ($ifswmode eq "1"){
#    			print "Vlan: trunk\n";
    			$outputline.="trunk\t";
    			
    			$vlancount=0;
    			@vlans="";
    			
    			##### 0-1023 ######
    			if (!defined($s->get_request($oid_trunkvlans.$ifindex))){
		    		print "Cannot determine interface vlans list 0-1023\n";
			}
			else {
    				$vlandump = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
#    				print "vlandump: $vlandump\n";
    				oid_trunkvlans_decode (substr($vlandump, 2), 0);
			}
				
			##### 1024-2047 #####
			if (!defined($s->get_request($oid_trunkvlans2k.$ifindex))){
		    		print "Cannot determine interface vlans list 1024-2047 \n";
			}
			else {
    				$vlandump = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
    				if($vlandump){
#    					print "2k vlandump: $vlandump\n";
    					oid_trunkvlans_decode (substr($vlandump, 2) , 1);
    				}
			}
			##### 2048-3071 #####
			if (!defined($s->get_request($oid_trunkvlans3k.$ifindex))){
		    		print "Cannot determine interface vlans list 2048-3071\n";
			}
			else {
    				$vlandump = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
    				
    				if($vlandump){
#    					print "3k vlandump: $vlandump\n";
						oid_trunkvlans_decode (substr($vlandump, 2), 2);
					}
			}
			##### 3072-4095 #####
			if (!defined($s->get_request($oid_trunkvlans4k.$ifindex))){
		    		print "Cannot determine interface vlans list 3072-4095 \n";
			}
			else {
    				$vlandump = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]}; 
    				
				if($vlandump && length $vlandump > 2){
#					print "4k vlandump: $vlandump\n";
					oid_trunkvlans_decode (substr($vlandump, 2), 3);
				}
    				
			}
				if($vlancount==4094){
					@vlans = ("ALL");
				}
#				print "Vlans: @vlans\nVlancount: $vlancount  \n";
    		}
    		else {
#    			print "Vlan: non-ethernet or interface shutdown\n";
				$outputline.="n/a\t";
    		}
	    	
	    }
	    
	    
	    ###### ifAlias ########
	    if (!defined($s->get_request($oid_ifalias.$ifindex))){
    		print "Cannot define ifAlias\n";
    	    }
    	    else {
    			$ifalias = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
			$outputline.="$ifalias\n";
    	   }
    	if($iftype == 6){
    		print "$outputline";
    		if($ifswmode eq "1"){
    			if($vlans[0] ne "ALL"){
    				print "\n\t=====>>>  Trunk port vlans:@vlans\n\t----------------------------------------------------\n";
    			}
    		}
    	}
    	
    	
    	###########Incrementing ifindex################
    	if (!defined($s->get_next_request($oid_ifindex.".".$ifindex))){
	    	print "Cannot define ifindex\n";
	    }
	    else {
    			$ifindex =  $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
    	}
    	$y++;
       	
	}
	

}


sub oid_trunkvlans_decode {
	@hexarray = split (//,$_[0]);

	$supbl=1024*$_[1];
	$curvlanbl=0;

	$z=0;

	while ($z<=$hexarraylen)
	{
		$z++;
		$ee=shift(@hexarray);
		$curvlanbl=($hexarraylen-1-$#hexarray)*4+$supbl;

		$val= hex "0x$ee";
		if ($val!=0)
		{
			$shift=1;
			for ($i=3;$i>=0;$i--)
			{
   				$shift = 1<< $i;
   				if($val & $shift)
   				{
   					$vlanid= $curvlanbl+3-$i;
   					$vlancount++;
   					push (@vlans ,$vlanid );
   				}
			}

		}
	}
	
	return 0;
} 





sub usage{
	
$script =  $0;

$script =~ s/^.*\/(\S+)$/$1/;

    print << "USAGE";

$script

Get info about cisco switch interfaces.

Usage: $script [-c community] <switch> 

Options: -c community		SNMP community.
         
(c) Alexey Grachev. 2009

USAGE
     exit 1;
}
	
	




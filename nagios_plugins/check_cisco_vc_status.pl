#!/usr/bin/perl -w
#  Copyright (c) 2009 Alexey Grachev <alxgrh [at] yandex [dot] ru>
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
#  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
#  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
#  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
#  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#  SUCH DAMAGE.
#
#

use strict;

use Net::SNMP;
use Getopt::Std;

$script =  $0;
$script =~ s/^.*\/(\S+)$/$1/;


my $version = "2c";
my $timeout = 2;

my $target_vc_index = 0;

my $oid_vcindex			= ".1.3.6.1.4.1.9.10.106.1.2.1.1";
my $oid_vcid			= ".1.3.6.1.4.1.9.10.106.1.2.1.10.";
my $oid_vcdescr			= ".1.3.6.1.4.1.9.10.106.1.2.1.22.";
my $oid_vcadminstatus		= ".1.3.6.1.4.1.9.10.106.1.2.1.25.";
my $oid_vcoperstatus		= ".1.3.6.1.4.1.9.10.106.1.2.1.26.";
my $oid_vcinboundoperstatus	= ".1.3.6.1.4.1.9.10.106.1.2.1.27.";
my $oid_vcoutboundoperstatus	= ".1.3.6.1.4.1.9.10.106.1.2.1.28.";



my $oid_sysdescr 		= ".1.3.6.1.2.1.1.1.0";
my $oid_ifnumber		= ".1.3.6.1.2.1.2.1.0";		
my $oid_ifdescr 		= ".1.3.6.1.2.1.2.2.1.2.";
my $oid_iftype		= ".1.3.6.1.2.1.2.2.1.3.";	
my $oid_ifmtu		= ".1.3.6.1.2.1.2.2.1.4.";
my $oid_ifspeed		= ".1.3.6.1.2.1.2.2.1.5.";
my $oid_ifphysaddress	= ".1.3.6.1.2.1.2.2.1.6.";
my $oid_ifadminstatus	= ".1.3.6.1.2.1.2.2.1.7.";
my $oid_ifoperstatus	= ".1.3.6.1.2.1.2.2.1.8.";
my $oid_iflastchange	= ".1.3.6.1.2.1.2.2.1.9.";
my $oid_ifinerrors	= ".1.3.6.1.2.1.2.2.1.14.";
my $oid_ifouterrors	= ".1.3.6.1.2.1.2.2.1.20.";
my $oid_ifoutqlen	= ".1.3.6.1.2.1.2.2.1.21.";

# Cisco Specific



my $hostname = "192.168.10.21";
my $returnstring = "";

my $community = "public"; 		# Default community string


if (@ARGV < 1) {
     print "Too few arguments\n";
     usage();
}


my ($opt_h,$opt_H,$opt_C,$opt_v);

use Getopt::Long;
&Getopt::Long::config('bundling');
GetOptions(
        "h"   => \$opt_h,       
        "C=s" => \$opt_C,
        "H=s" => \$opt_H,    
        "v=s" => \$opt_v,
);
my $target_vc=1;
getopts("h:H:C:v:w:c:");
if ($opt_h){
    usage();
    exit(0);
}
if ($opt_H){
    $hostname = $opt_H;
}
else {
    print "No hostname specified\n";
    usage();
    exit(0);
}
if ($opt_C){
    $community = $opt_C;
}
if ($opt_v){
    $target_vc = $opt_v;
}

# Create the SNMP session

my $oid_sysDescr = ".1.3.6.1.2.1.1.1.0";
my ($s, $e) ;
$version = "1";
($s, $e) = Net::SNMP->session(
   -community    =>  $community,
   -hostname     =>  $hostname,
   -version      =>  $version,
   -timeout      =>  $timeout,
);

if (!defined($s->get_request($oid_sysDescr))) {
  $s->close();
  sleep 0.5;
  $version = "2c";
  ($s, $e) = Net::SNMP->session(
    -community    =>  $community,
    -hostname     =>  $hostname,
    -version      =>  $version,
    -timeout      =>  $timeout,
  );
  if (!defined($s->get_request($oid_sysDescr))) {
    print "Agent not responding, tried SNMP v1 and v2\n";
    exit(1);
  }
}

my $status=0;
if (find_match() == 0){
    probe_vc();
}
else {
    $status = 2;
    print "VC $target_vc not found on device $hostname\n";
    exit $status;
}
    
# Close the session
$s->close();

if($status == 0){
    print "Status is OK - $returnstring\n";
    exit $status;
}
elsif($status == 1){
    print "Status is a Warning Level - $returnstring\n";
    exit $status;
}
elsif($status == 2){
    print "Status is CRITICAL - $returnstring\n";
    exit $status;
}
else{
    print "Plugin error! SNMP status unknown\n";
    exit $status;
}

exit 2;


#################################################
# Finds match for supplied vcid 
#################################################
my $vcid=222;
sub find_match {

    my ($oid_temp,@str_temp,$ind_temp);
    $target_vc_index=0;
    $oid_temp = $oid_vcid;
while ( 1 ) {
    if (!defined($s->get_next_request($oid_temp))) { 
    }
    else {
            @str_temp=$s->var_bind_names();
            $ind_temp= pop(@str_temp);
            @str_temp=split(/\./,$ind_temp);
            $ind_temp=pop(@str_temp);
            if ($target_vc_index>$ind_temp){
                return 1;
            }
            $target_vc_index=$ind_temp;
	    $oid_temp= $oid_vcid . $target_vc_index;
        foreach ($s->var_bind_names()) {
            $vcid = $s->var_bind_list()->{$_};
            if ($vcid == $target_vc){
		return 0; 
	    }
	    
        }
    }
   
}

    if ($target_vc_index == 0){
        return 1;
    }
    else {
        return 0;
    }
}

####################################################################
# Gathers data about target VC                                     #
####################################################################


sub probe_vc {

my ($oid_temp,$vcdescr,$vcoperstatus,$vcinboundoperstatus,$vcoutboundoperstatus,$vcadminstatus,$errorstring,$vcopst,$vcinopst,$vcoutopst,$vcadmst,$temp);
    $oid_temp = $oid_vcdescr . $target_vc_index;    
    if (!defined($s->get_request($oid_temp))) {
    }
    else {
        foreach ($s->var_bind_names()) {
            $vcdescr = $s->var_bind_list()->{$_};
        }
    }
    ############################
    
    $oid_temp = $oid_vcoperstatus . $target_vc_index;    
    if (!defined($s->get_request($oid_temp))) {
    }
    else {
        foreach ($s->var_bind_names()) {
            $vcoperstatus = $s->var_bind_list()->{$_};
        }
    }
    ############################
    
     
    $oid_temp = $oid_vcinboundoperstatus . $target_vc_index;    
    if (!defined($s->get_request($oid_temp))) {
    }
    else {
        foreach ($s->var_bind_names()) {
            $vcinboundoperstatus = $s->var_bind_list()->{$_};
        }
    }
    ############################
        
    $oid_temp = $oid_vcoutboundoperstatus . $target_vc_index;    
    if (!defined($s->get_request($oid_temp))) {
    }
    else {
        foreach ($s->var_bind_names()) {
            $vcoutboundoperstatus = $s->var_bind_list()->{$_};
        }
    }
    ############################
                
    $oid_temp = $oid_vcadminstatus . $target_vc_index;    
    if (!defined($s->get_request($oid_temp))) {
    }
    else {
        foreach ($s->var_bind_names()) {
            $vcadminstatus = $s->var_bind_list()->{$_};
        }
    }
    ############################
        
        
    $errorstring = "";
    
    # Sets warning / critical levels if interface down
    
    if ($vcadminstatus eq "1"){ $vcadmst = "UP";
    }
    else {
        $status = 2;
	$vcadmst = "DOWN";
        $errorstring = "VC ADMINISTRATIVELY DOWN:";
    }

        
    if ($vcoperstatus eq "1"){ $vcopst = "UP";
    }
    else {
        $status = 2;
	$vcopst = "DOWN";
        $errorstring = "VC DOWN:";
    }
     
     
    if ($vcinboundoperstatus eq "1"){ $vcinopst = "UP";
    }
    else {
        $status = 2;
	$vcinopst = "DOWN";
    }

    if ($vcoutboundoperstatus eq "1"){ $vcoutopst = "UP";
    }
    else {
        $status = 2;
        $vcoutopst = "DOWN";
    }


    
    if ($status == 0){    
        $temp = sprintf "$vcid - $vcdescr  -  Operstatus:$vcopst Adminstatus:$vcadmst Inbound:$vcinopst Outbound:$vcoutopst";
        $returnstring .= $temp;
    }
    else {
        $temp = sprintf "$errorstring $vcid - $vcdescr  -  Operstatus:$vcopst Admin:$vcadmst Inbound:$vcinopst Outbound:$vcoutopst";
        $returnstring .= $temp;
    }
}

####################################################################
# help and usage information                                       #
####################################################################

sub usage {
    print << "USAGE";
--------------------------------------------------------------------
$script v$script_version

Monitors status of specific VC. 

Usage: $script -H <hostname> -c <community> -v <vcid> [...]

Options: -H 	Hostname or IP address
         -C 	Community (default is public)
	 -v 	Target VC  ID 

(c)Alexey Grachev. 2009.
USAGE
     exit 1;
}



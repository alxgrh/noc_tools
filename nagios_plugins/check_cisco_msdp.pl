#!/usr/bin/perl
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


use Net::SNMP;
use Getopt::Std;

$script =  $0;
$script =~ s/^.*\/(\S+)$/$1/;


$version = "2c";
$timeout = 2;

$number_of_interfaces = 0;
$target_vc_index = 0;

$oid_sacacheentries		= ".1.3.6.1.3.92.1.1.3.0";
$oid_msdppeerstate		= ".1.3.6.1.3.92.1.1.5.1.3.";
$oid_mroutecacheentries		= ".1.3.6.1.2.1.83.1.1.7.0";






$critical	=0;	
$warning	=0;
$hostname = "192.168.10.21";
$returnstring = "";

$community = "public"; 	


if (@ARGV < 1) {
     print "Too few arguments\n";
     usage();
}

getopts("hH:C:w:c:p:");
if ($opt_h){
    usage();
    exit(0);
}
if ($opt_H){
    $hostname = $opt_H;
    # print "Hostname $opt_H\n";
}
else {
    print "No hostname specified\n";
    usage();
    exit(0);
}
if ($opt_C){
    $community = $opt_C;
}
if ($opt_p){
    $peer = $opt_p;
}
else {
    print "No peer specified\n";
    usage();
    exit(0);
}
if ($opt_w){
    $warning = $opt_w;
}
if ($opt_c){
    $critical = $opt_c;
}


# Create the SNMP session

$oid_sysDescr = ".1.3.6.1.2.1.1.1.0";		

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

#####################MSDP Peer state

$oid_temp = $oid_msdppeerstate . $peer;
if (!defined($s->get_request($oid_temp))) {
	print "CRITICAL - Can't get peer state info";
	exit (2);
}
else {
   foreach ($s->var_bind_names()) {
        $msdppeerstate = $s->var_bind_list()->{$_};
   }
}

###################SA cache entries    
if (!defined($s->get_request($oid_sacacheentries))) {
	$sacacheentries="n/a";
}
else {
   foreach ($s->var_bind_names()) {
        $sacacheentries = $s->var_bind_list()->{$_};
   }
}

#################MRoute cache entries
if (!defined($s->get_request($oid_mroutecacheentries))) {
}
else {
   foreach ($s->var_bind_names()) {
        $mrcacheentries = $s->var_bind_list()->{$_};
   }
}
################Output
$output ="Peer:$peer";

if($msdppeerstate eq "1")
{
        $state="inactive";
        print "Peer CRITICAL - Peer:$peer state:$state";
        exit(2);
}
if($msdppeerstate eq "2")
{
        $state="listen";
        print "Peer CRITICAL - Peer:$peer state:$state";
        exit(2);

}
if($msdppeerstate eq "3")
{
        $state="connecting";
        print "Peer CRITICAL - Peer:$peer state:$state";
        exit(2);

}
if($msdppeerstate eq "4")
{
        $state="established";
        $status=0;
}
if($msdppeerstate eq "5")
{
        $state="disabled";
        print "Peer CRITICAL - Peer:$peer state:$state";
        exit(2);

}

if($sacacheentries eq "n/a"){
	print "Peer WARNING - Peer:$peer state:$state can't get sa-cache count";
}
if($sacacheentries<$warning){
	if($sacacheentries<$critical){
		print "Peer CRITICAL - Peer:$peer state:$state SA cache entries:$sacacheentries Mroute cache entries:$mrcacheentries";
		exit (2);	
	}
	else {
		print "Peer WARNING - Peer:$peer state:$state SA cache entries:$sacacheentries Mroute cache entries:$mrcacheentries";
		exit (1);
	}
}
else{
	print "Peer OK - Peer:$peer state:$state SA cache entries:$sacacheentries Mroute cache entries:$mrcacheentries";
	exit(0);
}

$returnstring ="Peer: $peer state: $msdppeerstate \n";
$s->close();



######################Usage
sub usage {
    print << "USAGE";
--------------------------------------------------------------------
$script 

Monitors status of MSDP peer 

Usage: $script -H <hostname> -C <community> -p <peer> -w <warn> -c <crit>

Options: -H 	Hostname or IP address
         -C 	Community (default is public)
	 -p	peer IPaddress
	 -w	Warning threshold - number of entries in sa-cache
	 -c	Critical threshold - number of entries in sa-cache

(c) Alexey Grachev 2009
USAGE
     exit 1;
}



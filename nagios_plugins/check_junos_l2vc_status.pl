#!/usr/bin/perl -w
#  Copyright (c) 2011 Alexey Grachev <alxgrh [at] yandex [dot] ru>
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


my $script =  $0;

$script =~ s/^.*\/(\S+)$/$1/;

# SNMP options
my $version = "2c";
my $timeout = 2;

my $oid_associated_if		= ".1.3.6.1.4.1.2636.3.26.1.4.1.6.5";
my $oid_ifdescr			= ".1.3.6.1.2.1.2.2.1.2.";
my $oid_l2vc_status		= ".1.3.6.1.4.1.2636.3.26.1.4.1.15.5";
my $oid_local_vcid		= ".1.3.6.1.4.1.2636.3.26.1.4.1.7.5";
my $oid_peerIP			= ".1.3.6.1.4.1.2636.3.26.1.4.1.10.5";
my $oid_sysdescr 		= ".1.3.6.1.2.1.1.1.0";


my ($target_interface,$hostname);
my $community = "public"; 		# Default community string


if (@ARGV < 1) {
     print "Too few arguments\n";
     usage();
}


my ($opt_h,$opt_H,$opt_C,$opt_i);

use Getopt::Long;
&Getopt::Long::config('bundling');
GetOptions(
        "h"   => \$opt_h,
        "C=s" => \$opt_C,
        "H=s" => \$opt_H,
        "i=s" => \$opt_i,
);

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
if ($opt_i){
    $target_interface = $opt_i;
}
else {
    print "No attached interface specified\n";
    usage();
    exit(0);
}


# Create the SNMP session

my ($s, $e) ;
$version = "1";
($s, $e) = Net::SNMP->session(
   -community    =>  $community,
   -hostname     =>  $hostname,
   -version      =>  $version,
   -timeout      =>  $timeout,
);

if (!defined($s->get_request($oid_sysdescr))) {
  $s->close();
  sleep 0.5;
  $version = "2c";
  ($s, $e) = Net::SNMP->session(
    -community    =>  $community,
    -hostname     =>  $hostname,
    -version      =>  $version,
    -timeout      =>  $timeout,
  );
  if (!defined($s->get_request($oid_sysdescr))) {
    print "Agent not responding, tried SNMP v1 and v2\n";
    exit(1);
  }
}

#convert interface name to numeric OID view
my $oid_interafce = "." . length $target_interface;
foreach (split //, $target_interface) {
        $oid_interafce .= "." . (ord $_)  ;
}

my $status_string = "";
my $vc_status_code = 0;
my $peer_ip = "";
my $vcid = 0;
my $int_index = 0;
my $int_descr = "";

#Get associated interface index
if (!defined($s->get_next_request($oid_associated_if . $oid_interafce))) {
        print  "SNMP error. Cannot get interface index";
        exit 1;
}
else {
        $int_index = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
}

#Get interface description
if (!defined($s->get_request($oid_ifdescr . $int_index))) {
        print "SNMP error. Cannot get interface description";
        exit 1;
}
else {
        $int_descr = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
}

#Check if inteface is correct
if ($int_descr ne $target_interface) {
	print "WARNING. No L2VC configured on $target_interface";
	exit 1;
}


#Get L2VC status
if (!defined($s->get_next_request($oid_l2vc_status . $oid_interafce))) {
	print "SNMP error. Cannot get VC status";
	exit 1;
}
else {
	$vc_status_code = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]}; 
}

#Get peer IP address 
if (!defined($s->get_next_request($oid_peerIP . $oid_interafce))) {
        print "SNMP error. Cannot get peer IP address";
	exit 1;
}
else {
        $peer_ip = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
}

#Get local vcid
    if (!defined($s->get_next_request($oid_local_vcid . $oid_interafce))) {
        print "SNMP error. Cannot get local VCID";
        exit 1;
    }
    else {
        $vcid = $s->var_bind_list()->{@{[$s->var_bind_names()]}[0]};
    }
    
# Close the session
$s->close();

#Check status
my $status;
if ($vc_status_code == 0){
	$status_string = "Warning. VC status is UNKNOWN. Peer: $peer_ip. VCID: $vcid. Local interface: $target_interface";
	$status = 1;
}
if ($vc_status_code == 1){
	$status_string = "Critical. VC status is DOWN. Peer: $peer_ip. VCID: $vcid. Local interface: $target_interface";
	$status = 2;
}
if ($vc_status_code == 2){
        $status_string = "OK. VC status is UP. Peer: $peer_ip. VCID: $vcid. Local interface: $target_interface";
        $status = 0;
}
if ($vc_status_code !=0 && $vc_status_code !=1 && $vc_status_code !=2) {
	$status_string = "Somthing wrong. Check the nagios plugin source. VC status code: $vc_status_code";
	$status = 1;
}
print $status_string;
exit $status;




####################################################################
# help and usage information                                       #
####################################################################

sub usage {
    print << "USAGE";
--------------------------------------------------------------------

Monitors status of l2circuit attached to specific interface. 

Usage: $script -H <hostname> -c <community> [...]

Options: -H 	Hostname or IP address
         -C 	Community (default is public)
	 -i 	Interface attached to l2circuit 

(c) Alexey Grachev. 2011.
USAGE
     exit 1;
}


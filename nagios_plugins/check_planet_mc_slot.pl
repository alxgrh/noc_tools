#!/usr/bin/perl
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


use Net::SNMP;
use Getopt::Std;

$script    = "check_snmp_mc_slot";

# SNMP options
$version = "2c";
$timeout = 2;

$number_of_interfaces = 0;
$target_vc_index = 0;


$oid_optlinkstate = ".1.3.6.1.4.1.10456.2.536.4.2.1.7.";




$hostname = "192.168.10.21";
$returnstring = "";

$community = "public"; 		# Default community string

# Do we have enough information?
if (@ARGV < 1) {
     print "Too few arguments\n";
     usage();
}

getopts("hH:C:s:");
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
if ($opt_s){
    $slot = $opt_s;
}
else {
    print "No slot specified\n";
    usage();
    exit(0);
}


# Create the SNMP session

$oid_sysDescr = ".1.3.6.1.2.1.1.1.0";		# Used to check whether SNMP is actually responding

$version = "1";
($s, $e) = Net::SNMP->session(
   -community    =>  $community,
   -hostname     =>  $hostname,
   -version      =>  $version,
   -timeout      =>  $timeout,
);

if (!defined($s->get_request($oid_sysDescr))) {
  # If we can't connect using SNMPv1 lets try as SNMPv2
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

#####################Optical link state##########

if (!defined($s->get_request($oid_optlinkstate.$slot))) {
	print "CRITICAL - Can't get optical link state for slot $slot";
	exit (2);
}
else {
   foreach ($s->var_bind_names()) {
        $optlinkstate = $s->var_bind_list()->{$_};
   }
}

################Output

if($optlinkstate eq "1")
{
        $state="UP";
        print "Optical link OK - Slot:$slot link state:$state";
        exit(0);
}
if($optlinkstate eq "2")
{
        $state="DOWN";
        print "Optical link CRITICAL - Slot:$slot link state:$state";
        exit(2);

}
if($optlinkstate eq "3")
{
        $state="unplugged";
        print "Optical link CRITICAL - Slot:$slot link state:$state";
        exit(2);

}


######################Usage
sub usage {
    print << "USAGE";
--------------------------------------------------------------------
$script 

Monitors status of MC slot

Usage: $script -H <hostname> -C <community> -s <slot> 

Options: -H 	Hostname or IP address
         -C 	Community (default is public)
         -s	MC slot number

(c) ALexey Grachev. 2009.
USAGE
     exit 1;
}

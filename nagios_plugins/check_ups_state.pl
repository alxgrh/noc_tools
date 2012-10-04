#!/usr/bin/perl
#  Copyright (c) 2010 Alexey Grachev <alxgrh [at] yandex [dot] ru>
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


#use strict ;

use Net::SNMP;
use Getopt::Std;
use Switch;

my $oid_state = ".1.3.6.1.4.1.318.1.1.1.11.1.1.0";
my $oid_sysdescr = ".1.3.6.1.2.1.1.1.0";

$warn="Warning conditions present: \n";
$crit="Critical conditions present: \n";
$status=0;

#my ($opt_h,$opt_c,$crit,$opt_w,$warn,$opt_C,$community,$hostname,$load);
getopts("c:h");

if ($opt_h){
    usage();
    exit(0);
}
if ($opt_c){
    $community = $opt_c;

}
else{
    usage();
    exit(0);
}

$hostname = $ARGV[0];
if(!$hostname){
   usage();
}

############Create SNMP session#########################
my ($s, $e) = Net::SNMP->session(
    -community    =>  $community,
    -hostname     =>  $hostname,
    -version      =>  "1",
    -timeout      =>  2,
);

my $state="";


n_snmp_request(\$state,$s,"GET",$oid_state) ? exit 1 : 0;


if($state  =~ /v000101..00000000001000000000000000000000000000000000000000000000/ ){
	print "OK - normal operation \n";
                exit(0);
}
@state_flags= split //,$state;

print $state;

###WARNING CONDITIONS###
if($state_flags[2] eq "1"){
	$warn .="Low Battery\n";
	$status=1;
}
if($state_flags[4] eq "1"){
        $warn .="Replace Battery\n";
	$status=1;
}
if($state_flags[22] eq "1"){
        $warn .="Smart Boost or Smart Trim Fault\n";
        $status=1;
}
if($state_flags[26] eq "1"){
        $warn .="Warning Battery Temperature\n";
        $status=1;
}
if($state_flags[44] eq "1"){
        $warn .="High Internal Temperature\n";
        $status=1;
}
if($status == 0){
        $warn ="No warning conditions.\n";
}


###CRITICAL CONDITIONS###
if($state_flags[0] eq "1"){
        $crit .="Abnormal Condition Present\n";
        $status=2;
}
if($state_flags[1] eq "1"){
        $crit .="On Battery\n";
        $status=2;
}
if($state_flags[8] eq "1"){
        $crit .="Overload\n";
        $status=2;
}
if($state_flags[10] eq "1"){
        $crit .="Batteries Discharged\n";
        $status=2;
}
if($state_flags[11] eq "1"){
        $crit .="Manual Bypass\n";
        $status=2;
}
if($state_flags[12] eq "1"){
        $crit .="Software Bypass\n";
        $status=2;
}
if($state_flags[13] eq "1"){
	$crit .="In Bypass due to Internal Fault\n";
        $status=2;
}
if($state_flags[14] eq "1"){
        $crit .="In Bypass due to Supply Failure\n";
        $status=2;
}
if($state_flags[15] eq "1"){
        $crit .="In Bypass due to Fan Failure\n";
        $status=2;
}
if($state_flags[20] eq "1"){
        $crit .="Battery Communication Lost\n";
        $status=2;
}
if($state_flags[23] eq "1"){
        $crit .="Bad Output Voltage\n";
        $status=2;
}
if($state_flags[24] eq "1"){
        $crit .="Battery Charger Failure\n";
        $status=2;
}
if($state_flags[25] eq "1"){
        $crit .="High Battery Temperature\n";
        $status=2;
}
if($state_flags[27] eq "1"){
        $crit .="Critical Battery Temperature\n";
        $status=2;
}
if($state_flags[29] eq "1"){
	$crit .="Low Battery / On Battery\n";
        $status=2;
}
if($state_flags[36] eq "1"){
        $crit .="Inverter DC Imbalance\n";
        $status=2;
}
if($state_flags[37] eq "1"){
        $crit .="Transfer Relay Failure\n";
        $status=2;
}
if($state_flags[40] eq "1"){
        $crit .="Electronic Unit Fan Failure\n";
        $status=2;
}
if($state_flags[41] eq "1"){
        $crit .="Main Relay Failure\n";
        $status=2;
}
if($state_flags[42] eq "1"){
        $crit .="Bypass Relay Failure\n";
        $status=2;
}
if($state_flags[45] eq "1"){
        $crit .="Battery Temperature Sensor Fault\n";
        $status=2;
}
if($state_flags[47] eq "1"){
        $crit .="DC Bus Overvoltage\n";
        $status=2;
}
if($state_flags[48] eq "1"){
        $crit .="PFC Failure\n";
        $status=2;
}
if($state_flags[49] eq "1"){
        $crit .="Critical Hardware Fault\n";
        $status=2;
}

switch ($status) {
	case 1 {
		print "WARNING\n$warn\n"
	} 
        case 2 {
                print "CRITICAL\n$warn\n$crit\n"
        }
        case 0 {
		$status=1;
                print "WARNING. Something wrong. State:$state. See .1.3.6.1.4.1.318.1.1.1.11.1.1 OID for details.\n\n"
        }

}
      
exit($status);
    



sub usage {

      print "check_ups_state.pl -c <community> hostname\n";
      exit (1);
}


sub n_snmp_request ($$$$){

	*var= shift;
	my ($ses, $req, $oid) = @_ ;

	if ($req eq "GET"){
	
		if (!defined($ses->get_request($oid))) {
			print $ses->error(),"\n";
			return 1;
		}
		else {
	                $var = $ses->var_bind_list()->{$oid} ;
			return 0;
		}
	}
	if ($req eq "GETNEXT"){

                if (!defined($ses->get_next_request($oid))) {
                        print $ses->error(),"\n";
                        return 1;
                }
                else {
                        $var = $ses->var_bind_list()->{@{[$ses->var_bind_names()]}[0]};
                        return 0;
                }
        }
	else {
		print "Unknown request\n";
		print "Usage: n_snmp_request(\\\$result_var,\$snmp_session_var,\"REQUEST Method(GET or GETNEXT)\",\$oid_var)";
		return 2;
	}

}

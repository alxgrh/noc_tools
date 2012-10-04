#!/usr/bin/perl
#
#  Copyright (c) 2011 Alexey Grachev <alxgrh at yandex dot ru>
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



$CFGDIR = "/noc/etc/";
$CFGFILE = "prfl-update.cfg";
$DATADIR = "/home/updater/public_html/";
$BASEURL = "http://updater:http_password\@srv.isp.org/~updater/";
$BGPQ = "/usr/local/bin/bgpq3";

$user="updater";
#Uncomment and set correct value if U use login/password authentication
$pass="telnet_password";

$|=1;
use Net::SSH::Expect; 
use POSIX qw(strftime);

sub now {
	return strftime "%Y.%m.%d %k:%M:%S ", localtime;
}


$complete_msg = now . "Starting prefix-lists update process.\n====\n\n";

open(CFG, $CFGDIR . $CFGFILE) or die "cannot open configuration file";

$complete_msg .= now . "Parsing config file.\n====\n";
while (<CFG>){
	@router_set = split /:/ , $_;

	if ($#router_set<2) {
		$complete_msg .= now . "Bad line in configuration: $_====\n";
		next;
	}
	if ($router_set[1] !~ /(JUNOS|IOS)/){
		$complete_msg .= now . "Unknown dialect $router_set[1] in line $_====\n";
		next;
	}
	$router = shift @router_set;
	$dialect = shift @router_set;
	$complete_msg .= now . "Processing router $router with dialect $dialect.\n"; 

	####Create SSH object#########	
	$ssh = Net::SSH::Expect->new( host => $router, user => $user,
                                        #Uncomment if U use login/password authentication
                                        password => $pass,
                                        raw_pty => 1 , timeout => 5 );

	if ($dialect eq "JUNOS") {
		###Login to Router###
		#Uncomment if U use key authentication
		$ssh->run_ssh();
		sleep 3;
		$cli_msg = $ssh->read_all(2); 	
	}
	
	if ($dialect eq "IOS") {
                ###Login to Router###

                #Uncomment if U use login/password authentication
                $cli_msg = $ssh->login();

                #Uncomment if U use key authentication
                #$ssh->run_ssh();
                sleep 3;

	}	

	###Enter to configure mode in JunOS
	if ($dialect eq "JUNOS") {
		if ($cli_msg =~ /updater@\S+>\s*\z/ ){
			$complete_msg .= now . "Login to $router sucsessful.\n";
		}
		else {
			$complete_msg .= now . "Login to $router failed.\n====\n";
			$ssh->close();
			next;
		}

		$ssh->send("configure exclusive");
		if(!$ssh->waitfor('updater@\S+#\s*\z', 1)){
			$complete_msg .= now . "Configuration prompt not found after 1 second, skip router processing.\n====\n";
			$ssh->close();
			next;
		}
		else {
			$complete_msg .= now . "Entering configure mode successful.\n";
		}
	}
	
	if ($dialect eq "IOS") {
		if ($cli_msg =~ /$router\#/ ){
                        $complete_msg .= now . "Login to $router sucsessful.\n";
                }
                else {
                        $complete_msg .= now . "Login to $router failed.\n====\n";
                        $ssh->close();
                        next;
                }
		#$cli_msg = $ssh->exec("configure terminal");
		#sleep 1;
		#if($cli_msg !~ /$router.config.\#/ ){
                #        $complete_msg .= now . "Configuration prompt not found after 1 second, skip router processing.\n====\n";
                #        $ssh->close();
                #        next;
                #}
                #else {
                #        $complete_msg .= now . "Entering configure mode successful.\n";
                #}

	}
	
	foreach $as_set (@router_set) {
		chomp $as_set;
		#Junos devices upload config
		if ($dialect eq "JUNOS") {
			if(system("$BGPQ -Jl $as_set $as_set > $DATADIR/$as_set.lst") == 0 ) {
				###Check for empty prefix-list
				@FSTAT  = stat ("$DATADIR/$as_set.lst");
				if ($FSTAT[7] - length $as_set != 47) {
					$cli_msg = $ssh->exec("load replace $BASEURL/$as_set.lst");
					if ($cli_msg =~ m/load complete\n/){
						$complete_msg .= now . "Upload $as_set sucsessful.\n";
					}
					else {
						$complete_msg .= now . "Upload $as_set failed, error: $cli_msg.\n";
					}

				}
				else {
					$complete_msg .= now . "Empty prefix-list for $as_set, skip uploading.\n";

				}
			}
			else {
				$complete_msg .= now . "bgpq exits whith bad status.\n";
			}

		}
		#Cisco IOS devices upload config
		else {
			if(system("$BGPQ -l $as_set $as_set > $DATADIR/$as_set.clst") == 0 ) {
				###Check for empty prefix-list
				@FSTAT  = stat ("$DATADIR/$as_set.clst");
				if ($FSTAT[7] - length $as_set != 19) {
					$cli_msg = $ssh->exec ("copy $BASEURL/$as_set.clst running-config\n");
					if ($cli_msg =~ m/bytes copied in \S+ secs/){
						$complete_msg .= now . "Upload $as_set sucsessful.\n";
					}
					else {
						$complete_msg .= now . "Error occured while $as_set uploading: $cli_msg.\n";
					}
				}
				else {
					$complete_msg .= now . "Empty prefix-list for $as_set, skip uploading.\n";
				}
			}
			else {
				$complete_msg .= now . "bgpq exits whith bad status.\n";
			}
		}

	}
	#Junos devices commit changes
	if ($dialect eq "JUNOS") {
		$ssh->send("commit comment \"Autoupdate prefix-lists\"");
		#sleep 3;
		$cli_msg = $ssh->read_all(10);
		if ( $cli_msg =~ m/commit complete\n/){
			$complete_msg .= now . "Commit changes sucsessful.\n";
		}
		else {
			$complete_msg .= now . "Commit changes unsucsessful, error: $cli_msg\n";
		}

		$cli_msg = $ssh->exec("quit configuration-mode");
		if($cli_msg =~ m/Exiting configuration mode/){
			$complete_msg .= now . "Quit configuration mode.\n";
		}
	}

	#Cisco device write nvram
	if($dialect eq "IOS"){
		$ssh->send("write");
		$cli_msg = $ssh->read_all(20);
		if ( $cli_msg =~ m/\[OK\]/){
                        $complete_msg .= now . "Write nvram sucsessful.\n";
                }
                else {
                        $complete_msg .= now . "Write nvram unsucsessful, error: $cli_msg\n";
                }
	}
	
	$ssh->close();
	$complete_msg .= "====\n";
}

print "\n\n\n$complete_msg";
close CFG;



# (c) Alexey Grachev, aag@eltel.net. 2011.


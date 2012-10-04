#!/usr/bin/perl
#
#  Copyright (c) 2009 Alexey Grachev <alxgrh at yandex dot ru>
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

use XML::DOM;
use Net::SNMP;

$version           = "2c";
$timeout           = 2;
$oid_sysdescr      = ".1.3.6.1.2.1.1.1.0";
$oid_sysobjoid     = ".1.3.6.1.2.1.1.2";
$oid_physclass     = ".1.3.6.1.2.1.47.1.1.1.1.5";
$oid_physdescr     = ".1.3.6.1.2.1.47.1.1.1.1.2.";
$oid_physsn        = ".1.3.6.1.2.1.47.1.1.1.1.11.";
$oid_physmodelname = ".1.3.6.1.2.1.47.1.1.1.1.13.";
$oid_physname      = ".1.3.6.1.2.1.47.1.1.1.1.7.";

my $config;
if ( $ARGV[0] ) {
	$config = $ARGV[0];
}
else {
	$config = '/noc/etc/devices.xml';
}

my $parser = XML::DOM::Parser->new();
my $doc    = $parser->parsefile($config);

my @array;

foreach my $device ( $doc->getElementsByTagName('device') ) {
	$isactive = $device->getAttribute('active');
	$name =
	  $device->getElementsByTagName('name')->item(0)->getFirstChild->getData;
	$address =
	  $device->getElementsByTagName('address')->item(0)->getFirstChild->getData;

	$ro_comm =
	  $device->getElementsByTagName('ro_comm')->item(0)->getFirstChild->getData;
	$dialect =
	  $device->getElementsByTagName('dialect')->item(0)->getFirstChild->getData;

	if ( $isactive eq "yes" && $dialect eq "ios12" ) {
		print "Device: $name\n";
		( $s, $e ) = Net::SNMP->session(
			-community => $ro_comm,
			-hostname  => $address,
			-version   => $version,
			-timeout   => $timeout,
		);
		####check for agent response####
		if ( !defined( $s->get_request($oid_sysdescr) ) ) {
			print STDERR "SNMP agent not responding\n";

			#exit 1;
		}
		####check for SysOID#########
		if ( !defined( $s->get_next_request($oid_sysobjoid) ) ) {
			print STDERR "Cannot define SysObjectID\n";
		}
		else {
			foreach ( $s->var_bind_names() ) {
				$sysOID = $s->var_bind_list()->{$_};
			}
			$sysobj =
			  `snmptranslate -Ta -m CISCO-PRODUCTS-MIB $sysOID | cut -d : -f 3`;
			chomp $sysobj;
			print "SysOID: $sysobj\nInventory:\n";

		}
		######check for class table of physicall entries####
		if ( !defined( $s->get_table($oid_physclass) ) ) {
			print STDERR "Cannot get Physical class table\n";
		}
		else {
			@oid_array = $s->var_bind_names();
			$bind_hash = $s->var_bind_list();
			foreach (@oid_array) {
				$physclass = $bind_hash->{$_};
				if (   $physclass == 10
					|| $physclass == 9
					|| $physclass == 3 )
				{
					$_ =~ m/.*\.(\d+)/;
					$entityindex = $1;

					######check for physname####
					if (
						!defined(
							$s->get_request( $oid_physname . $entityindex )
						)
					  )
					{
						print STDERR "Cannot get Physical name entry\n";
					}
					else {
						$entityname =
						  $s->var_bind_list()->{ $oid_physname . $entityindex };
						print "Name : $entityname\n";
					}
					######check for physdescr####
					if (
						!defined(
							$s->get_request( $oid_physdescr . $entityindex )
						)
					  )
					{
						print STDERR "Cannot get Physical Descr entry\n";
					}
					else {
						$entitydescr = $s->var_bind_list()
						  ->{ $oid_physdescr . $entityindex };
						print "Descr : $entitydescr\n";
					}
					######check for serial number#####
					if (
						!defined(
							$s->get_request( $oid_physsn . $entityindex )
						)
					  )
					{
						print STDERR "Cannot get serial num\n";
					}
					else {
						$entitysn =
						  $s->var_bind_list()->{ $oid_physsn . $entityindex };
						print "SN : $entitysn\n";
					}
					######check for PID#####
					if (
						!defined(
							$s->get_request(
								$oid_physmodelname . $entityindex
							)
						)
					  )
					{
						print STDERR "Cannot get model name\n";
					}
					else {
						$entitypid = $s->var_bind_list()
						  ->{ $oid_physmodelname . $entityindex };
						print "PID : $entitypid\n\n";
					}

				}
			}
		}
	}

}

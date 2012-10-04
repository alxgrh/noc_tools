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

use Net::IRR;
use Getopt::Std;

getopts("g:c:");

if($opt_g && $opt_c) {
	print "Both [-g] and [-c] options are not allowed.\n\n";
	usage();
}
if($opt_g){
        require GraphViz;
        $graphfile=$opt_g;
	#layout - dot,neato,twopi,circo,fdp
        $gr = GraphViz->new( overlap => 'scalexy' ,  directed => false, layout =>'dot', edge => { dir => 'none',fontsize => 8}, node => {shape=>'box'});

}

if($opt_c){
	$searched_as_set = $opt_c;
}

if ($#ARGV<0){
	usage();
	exit 0;
}

$expanded = {};
$root_as_set = $ARGV[0];

my $host = 'whois.radb.net';

my $i = Net::IRR->connect( host => $host )
	or die "can't connect to $host\n";


$expanded{$root_as_set}=1;
if ($graphfile){
	graph_asset($root_as_set,0,$gr);
	$gr->as_svg("$graphfile");
	$i->disconnect();
	exit 0;
} 

if($searched_as_set){
	print_as_chain($root_as_set,0,$searched_as_set) . "\n";
	$i->disconnect();
	exit 0;
}

print_asset ($root_as_set,0);
$i->disconnect();

sub assorti($a, $b) {
	@aa=split(//, $a);
	@bb=split(//, $b);
	if ($aa[2] eq "-") {
		if ($bb[2] == '-') {
			return $a cmp $b; # as-macro and as-macro, text comparision
		} else {
			return -1; # as-macro is always less than ASn
		};
	} elsif ($bb[2] eq "-") {
		return 1; # as-macro is always less than ASn
	} else {
		return join("", @aa[2 .. $#aa]) <=> join("", @bb[2 .. $#bb]);
	};
};


sub print_asset {
	my $as_set = shift @_;
	my $depth = shift @_;

	print "$as_set ";
	if (my @ases = sort(assorti $i->get_as_set($as_set, 0))) {
		print scalar(@ases) . " members\n";
		foreach (@ases) {
			my $as = $_;
			print "\t" x $depth . "|-";
			if ($as =~ /AS\D/) {
				if (defined($expanded{$as})) { 
					print "$as is already expanded\n";
				} else { 
					$expanded{$as}=1;
					print_asset ($as, $depth+1);
				};
			} else {
				print "$as\n";
			}
		}
 	} else {
		print "none found\n";
	}
}

sub graph_asset {
	my $as_set = shift @_;
	my $depth = shift @_;
	my $g = shift @_;

	if (my @ases = $i->get_as_set($as_set, 0)) {
		foreach (@ases) {
			my $as = $_;
			if ($as =~ /AS\D/) {
				if (!defined($expanded{$as})) {
					$expanded{$as}=1;
					$g->add_edge ( $as => $as_set);
					graph_asset ($as, $depth+1, $g);
				}
			}
			else {
				$g->add_edge ( $as => $as_set);
			}
		}
	}
}

sub print_as_chain {
	my $as_set = shift @_;
	my $depth = shift @_;
	my $leaf = shift @_;

	my $found = 0;
        if (my @ases = $i->get_as_set($as_set, 0)) {
                foreach (@ases) {
                        my $as = $_;
			if ($as eq $leaf) { 
				return $leaf;
			}
                        if ($as =~ /AS\D/) {
                                if (!defined($expanded{$as})) {
                                        $expanded{$as}=1;
					my $res = print_as_chain($as,$depth+1,$leaf);
					if($res ne "0"){
						if ($depth == 0){
                                        		print "$as_set -> $as -> $res\n";
							$found=1; 
						}
						else {
							return "$as -> $res";
						}
					}	
                                }
                        }
                }
        }
	$depth==0 && $found==0 ? print "$leaf not found in $as_set\n" : return 0;
}

sub usage {

print << "USAGE";
Name:
	asntree.pl - tool to build AS-SET trees based on information from RIPE DB.
Usage:
	asntree.pl [-g graphfile.svg] [-c searched_as-set ] <as-set>\n
Options:
	<as-set> - AS-SET which will be the root of tree. If there is no other arguments AS-SET tree will be printed to terminal. 
	-g graphfile.svg - make AS-SET tree as SVG image.
	-c searched_as-set - print chain of AS-SETs from root "as-set" to leaf "searched_as-set"

USAGE

exit 0;
}

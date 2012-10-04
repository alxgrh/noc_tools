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

if ($#ARGV<1){
        usage();
        exit 0;
}

$pattern=$ARGV[0];
$file=$ARGV[1];
$file1="/home/alexey/maillog";

$type="n/a";

if($pattern=~ /^(\d{1,3}\.){3}(\d{1,3})$/){

#       print "ipaddrOK\n";
        if($2 > 255 ){
                print "Too big octet\n";
                exit 2;
        }
        $type="sa";

}
else{
        if($pattern=~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/(\d{1,2})/){
                if($2 > 32 ){
                        print "mask too long \n";
                        exit 2;
                }
                $mask=$2;
#               print "prefOK $1 / $mask\n";
                $type="pr";
        }
        else{
                print "Bad pattern\n";
                exit 2;
        }
}

build_regexp();

open (FILE, "$file") or die ("Cannot open $file");
while($line=<FILE>){
        if($line =~ m/$basereg/){
                $line=~ m/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;
                if ($type eq "sa"){
                        print $line;
                }
                else{
                        #$ippref1=~ m/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;
                        if($mask>=24){
                                $classo=4;
                                $oct=$4;
                                $base="$1\.$2\.$3\.";
                        }
                        else{
                                if($mask>=16){
                                        $classo=3;
                                        $oct=$3;
                                        $base="$1\.$2\.";
                                }
                                else{
                                        if($mask>8){
                                                $classo=2;
                                                $oct=$2;
                                                $base="$1\.";
                                        }
                                        else{
                                                $classo=1;
                                                $oct=$1;
                                                $base="";
                                        }
                                }
                        }
                        if($oct<=$broadoct && $oct>=$netoct){
                                print "$line";
                        }
                }
        }
}

close (FILE);

sub build_regexp{
        if ($type eq "sa"){
                $basereg=$pattern;
        }
        else{
                $pattern=~ m/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;
                if($mask>=24){
                        $classo=4;
                        $bitmask=256-(1<<(32-$mask));
                        $oct=$4;
                        $basereg="$1\\.$2\\.$3\\.";
                }
                else{
                        if($mask>=16){
                                $classo=3;
                                $bitmask=256-(1<<(24-$mask));
                                $oct=$3;
                                $basereg="$1\\.$2\\.";
                        }
                        else{
                                if($mask>8){
                                        $classo=2;
                                        $bitmask=256-(1<<(16-$mask));
                                        $oct=$2;
                                        $basereg="$1\\.";
                                }
                                else{
                                        $classo=1;
                                        $bitmask=256-(1<<(8-$mask));
                                        $oct=$1;
                                        $basereg="";
                                }
                        }
                }
                $netoct=$oct & $bitmask;
                $broadoct=$netoct+255-$bitmask;

                print "Oct:$oct Numoct:$classo Bitmask:$bitmask Netoct: $netoct Basereg: $basereg Broad: $broadoct\n";
        }
}
sub usage{

        print <<EOF;
        Usage:   ipgrep.pl <PATTERN> <file>
        Example: ipgrep.pl 81.23.45.7/26 /var/log/maillog
EOF
}


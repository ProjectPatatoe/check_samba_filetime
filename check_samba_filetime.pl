#!/usr/bin/perl
# Patrick Barnes
# version 20180823
# TODO:
#   need to have a resursive option
#   have final status (OK:# Warn:# Crit:#) as first line

use strict;
use warnings;
use Config::Simple;
use Getopt::Long;
use DateTime;
use DateTime::Format::Duration;
use DateTime::Format::Strptime qw();
use Filesys::SmbClient;

#=====options=====
my $debug = 0;
my $verbose = 0;
my $fileonly = 0;
my $recursiondir = 0; #TODO
my $smb_host = "";
my $smb_path_t = ""; #after hostname
my $smb_path = ""; #assembled (smb://$smb_host/$smb_path_t)
my $smb_user = "";
my $smb_pass = "";
my $smb_workgroup = "";
my $smb_authfile = "";
my $age_warn = "360"; #in minutes
my $age_crit = "1440"; #in minutes

my $result = GetOptions (
	"debug" => \$debug,
	"d"     => \$debug,
	"v=i"   => \$verbose,
	"fileonly" => \$fileonly,
	"smb_host=s"   => \$smb_host,
	"host=s"   => \$smb_host,
	"h=s"      => \$smb_host,
	"smb_path=s" => \$smb_path_t,
	"smb_user=s" => \$smb_user,
	"user=s"     => \$smb_user,
	"username=s" => \$smb_user,
	"smb_pass=s" => \$smb_pass,
	"pass=s"     => \$smb_pass,
	"password=s" => \$smb_pass,
	"smb_workgroup=s" => \$smb_workgroup,
	"workgroup=s"     => \$smb_workgroup,
	"domain=s"        => \$smb_workgroup,
	"smb_authfile=s"  => \$smb_authfile,
	"age_warn=i"      => \$age_warn,
	"w=i"  => \$age_warn,
	"c=i"  => \$age_crit,
	"age_crit=i"  => \$age_crit
);
$smb_path = "smb://".$smb_host."/".$smb_path_t;
if ($debug) { $verbose = 3; }
if ($smb_authfile) {
	my $cfg = new Config::Simple($smb_authfile);
	if ($cfg->param('username')) {$smb_user = $cfg->param('username');}
	if ($cfg->param('password')) {$smb_pass = $cfg->param('password');}
	if ($cfg->param('domain'))   {$smb_workgroup = $cfg->param('domain');}
	if ($cfg->param('workgroup')){$smb_workgroup = $cfg->param('workgroup');}
}
#=====vars=====
my $warnings = 0;
my $criticals = 0;
my $oks = 0;
my $smb = new Filesys::SmbClient (
	username => $smb_user,
	password => $smb_pass,
	workgroup => $smb_workgroup
	);

my $dt_dur_format_full = DateTime::Format::Duration->new(
	pattern => '%Y years, %m months, %e days, %H hours, %M minutes, %S seconds'
);
#my $dt_dur_format_short = DateTime::Format::Duration->new(
#	pattern => '%e:%H:%M:%S'
#);
my $dt_now = DateTime->now(); #current time
if ($debug) {
	print "dt_now :",$dt_now,"\n";
}
if ($verbose >= 2) {
	print "smb_host  :",$smb_host,"\n";
	print "smb_path  :",$smb_path,"\n";
	print "age_warn  :",$age_warn,"\n";
	print "age_crit  :",$age_crit,"\n";
}
if ($verbose >= 3) {
	print "Result    :",$result,"\n";
	print "smb_user  :",$smb_user,"\n";
	if ($smb_pass) { print "smb_pass  :(something)\n"; }
	else { print "smb_pass  :(EMPTY!)\n"; }
	print "smb_workgroup :",$smb_workgroup,"\n";
	print "smb_authfile  :",$smb_authfile,"\n";
}

#=====Connect=====
if ($verbose >= 3) { print "Connecting...\n"; }
my $fd = $smb->opendir($smb_path); #handle dir
if ( ! defined $fd ) {print "Error: Could not connect?\n";exit 3;}
my @dirarr;
if ($verbose >= 3) { print "Building List"; }
while (my $f = $smb->readdir_struct($fd)) {
	if ($verbose >= 3) { print "."; }
	if ( ($f->[1] eq ".") || ($f->[1] eq "..") ) { next; }
	if ($fileonly && ($f->[0] == SMBC_DIR) )
	{
		next; #nothing, skip directories
	}
	else {
		push @dirarr, $f;
	}
}
if ($verbose >= 3) { print "\n"; }

#loop var predec
my $dt = -1;
my $dt_diff = -1;
my $dt_diff_min = -1;
if ($debug) { print "Stat'ing"; }
foreach my $n (@dirarr) {
	if ($debug) { print "-------------------------\n"; }
	if ($debug) { print "Loop2->\n"; }
	#var reset
	$dt = -1;
	$dt_diff = -1;
	$dt_diff_min = -1;

	#if ($verbose == 2) { print $n->[1]; }
	#elsif ($verbose >= 3) { print $smb_path,"/",$n->[1]; }

	my @fstat = $smb->stat($smb_path."/".$n->[1]);

	$dt = DateTime->from_epoch( epoch => $fstat[11]);
	if ( $dt )
	{
		#time diff test
		$dt_diff = $dt_now->delta_ms($dt); #minutes and seconds
		$dt_diff_min = $dt_diff->in_units('minutes');

		if ($dt_diff_min > $age_crit) {
			if ($verbose == 1) { print "CRIT ".$n->[1].","; }
			elsif ($verbose == 2) { print "CRIT ".$n->[1]."\n"; }
			elsif ($verbose >= 3) { print "CRIT ".$dt." ".$smb_path,"/",$n->[1]."\n"; }
			++$criticals;
		}
		elsif ($dt_diff_min > $age_warn) {
			if ($verbose == 1) { print "Warn".$n->[1].","; }
			elsif ($verbose == 2) { print "Warn ".$n->[1]."\n"; }
			elsif ($verbose >= 3) { print "Warn ".$dt." ".$smb_path,"/",$n->[1]."\n"; }
			++$warnings;
		}
		else {
			if ($verbose == 2) { print "ok   ".$n->[1]."\n"; }
			elsif ($verbose >= 3) { print "ok   ".$dt." ".$smb_path,"/",$n->[1]."\n"; }
			$oks++;
		}
	}
	else {print "dt NULL\n";}

	if ($debug) {
		print "raw          :",$n,"\n";
		if ($dt) {
			print "Datetime     :",$dt," \n";
			print "dt_diff      :",$dt_dur_format_full->format_duration($dt_diff),"\n";
		}
		else {
			print "Datetime     :undef \n";
			print "dt_diff      :",$dt_diff,"\n";
		}
		print "dt_diff(min) :",$dt_diff_min,"\n";
	}
	#last; ##TEST
}
if ($debug) { print "---------------End Loop---------------\n";}
$smb->close($fd);

##results
print  "OK:",$oks,"  Warn:",$warnings,"  Crit:",$criticals,"\n";

if ($debug) { print "!!!---Exiting...---!!!\n"; }

if ($criticals > 0 ) { exit 2; }
elsif ($warnings > 0 ) { exit 1; }
elsif ($oks > 0 ) { exit 0; }
else { exit 3; } #everything 0
#error / unknown return 3

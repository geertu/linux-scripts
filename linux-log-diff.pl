#!/usr/bin/perl -w

#
# © Copyright 2010 by Geert Uytterhoeven
#
# This file is subject to the terms and conditions of the GNU General Public
# License.
#

# FIXME link failures and other unhandled errors?
# FIXME section mismatches and other unhandled warnings?
# FIXME separate errors and warnings completely, i.e. 2 passess using a generic
#	common routine?

$esc_red = "\e[31m";
$esc_green = "\e[32m";
$esc_rm = "\e[0m";

sub usage() 
{
	my $name = $0;
	$name =~ s@.*/@@g;
	die <<EOF;

Usage: $name [options] oldlog newlog

Valid options:
	-h, --help	Display this help
	-d, --debug	Enable debug mode
	-v, --verbose	Enable verbose mode
EOF
}

sub set_common_prefix()
{
    my $s = shift;

    return if $s !~ m{^/};
    return if $s =~ m{^/opt/};
    return if $s =~ m{^/tmp/};
    return if $s =~ m{^/usr/};
    if (defined($common_prefix)) {
	chop $common_prefix while ($s !~ /^\Q$common_prefix\E/);
    } else {
	$common_prefix = $s;
    }
}

sub add()
{
    my $db = shift;
    my $log = shift;
    my $file = shift;
    my $loc = shift;
    my $msg = shift;

    $db->{$file}{$msg}{$log}{$loc} = 1;
    &set_common_prefix($file);
}

sub process()
{
    my $log = shift;

    open(LOG, "<$log") or die "Cannot open $log";
    while ($line = <LOG>) {
	chomp($line);

	if (($file, $loc, $msg) =
	    $line =~ m{(^[^:]*):([0-9:]+):\s*(error:\s*.*$)}i) {
	    &add(\%errors, $log, $file, $loc, $msg);
	} elsif (($file, $msg) =
	    $line =~ m{(^[^:]*):\s*(error in\s*.*$)}i) {
	    &add(\%errors, $log, $file, "N/A", $msg);
	} elsif (($file, $loc, $msg) =
	    $line =~ m{(^[^:]*):([0-9:]+):\s*(warning:\s*.*$)}i) {
	    &add(\%warnings, $log, $file, $loc, $msg);
	} elsif (($msg) = $line =~ m{(warning:\smodpost.*$)}i) {
	    &add(\%warnings, $log, "modpost", "N/A", $msg);
	} elsif ($debug) {
	    # FIXME
	    print STDERR "Unhandled error: $line\n" if ($line =~ /error/i);
	    print STDERR "Unhandled warning: $line\n" if ($line =~ /warn/i);
	}
    }
    close(LOG);
}

while (defined($ARGV[0])) {
	$option = $ARGV[0];
	last if not $option =~ /^-/;
	if ($option eq '-h' or $option eq '--help') {
		&usage();
	} elsif ($option eq '-v' or $option eq '--debug') {
		$debug = 1;
	} elsif ($option eq '--') {
		shift @ARGV;
		last;
	} else {
		print STDERR "Unknown option $option\n";
		&usage();
	}
	shift @ARGV;
}

&usage if ($#ARGV != 1);

$log1 = $ARGV[0];
$log2 = $ARGV[1];

&process($log1);
&process($log2);

sub print_report
{
    my %db = %{$_[0]};

    my ($file, $msgs, $msg, $logs);
    my @regressions = ();
    my @improvements = ();

    while (($file, $msgs) = each %db) {
	$file =~ s@^$common_prefix@@;
	while (($msg, $logs) = each %$msgs) {
	    my @msgs1 = keys %{$logs->{$log1}};
	    my @msgs2 = keys %{$logs->{$log2}};
	    next if $#msgs1 == $#msgs2 and !$verbose;
	    my $line = "$file: $msg: " . join(', ', @msgs1) . " => " .
		    join(', ', @msgs2) . "\n";
	    if ($#msgs1 < $#msgs2) {
		print "NEW  : $line" if $verbose;
		push @regressions, $line;
	    } elsif ($#msgs1 > $#msgs2) {
		print "FIXED: $line" if $verbose;
		push @improvements, $line;
	    } elsif ($verbose) {
		print "$line";
	    }
	}
    }

    $n = $#regressions + 1;
    if ($n) {
	print "\n$n regressions:\n\t";
	print join("\t", sort @regressions);
    }
    $n = $#improvements + 1;
    if ($n) {
	print "\n$n improvements:\n\t";
	print join("\t", sort @improvements);
    }
}

print "\n*** ERRORS ***\n";
print_report(\%errors);
print "\n\n*** WARNINGS ***\n";
print_report(\%warnings);


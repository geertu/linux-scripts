#!/usr/bin/perl -w

#
# © Copyright 2010 by Geert Uytterhoeven
#
# This file is subject to the terms and conditions of the GNU General Public
# License.
#

sub usage()
{
	my $name = $0;
	$name =~ s@.*/@@g;
	die <<EOF;

Usage: $name [options] oldlog newlog

Valid options:
	-h, --help	Display this help
	-d, --debug	Enable debug mode
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

sub add_record()
{
    my $db = shift;
    my $log = shift;
    my $file = shift;
    my $loc = shift;
    my $msg = shift;

    $db->{$file}{$msg}{$log}{$loc} = 1;
    &set_common_prefix($file);
}

sub read_log()
{
    my $log = shift;
    my ($line, $file,$loc, $msg);

    open(LOG, "<$log") or die "Cannot open $log";
    while ($line = <LOG>) {
	chomp($line);

	if (($file, $loc, $msg) =
	    $line =~ m{(^[^:]*):([0-9:]+):\s*(error:\s*.*$)}i) {
	    # compile error
	    &add_record(\%errors, $log, $file, $loc, $msg);
	} elsif (($msg) = $line =~ m{error: (.*undefined!)}i) {
	    # link error: undefined symbol
	    &add_record(\%errors, $log, "error", "N/A", $msg);
	} elsif (($file, $msg) =
	    $line =~ m{(^[^:]*):\s*(error in\s*.*$)}i) {
	    # link error
	    &add_record(\%errors, $log, $file, "N/A", $msg);
	} elsif (($file, $loc, $msg) =
	    $line =~ m{(^[^:]*):([0-9:]+):\s*(warning:\s*.*$)}i) {
	    # compile warning
	    &add_record(\%warnings, $log, $file, $loc, $msg);
	} elsif (($msg) = $line =~ m{(warning:\smodpost.*$)}i) {
	    # modpost warning
	    &add_record(\%warnings, $log, "modpost", "N/A", $msg);
	} elsif ($line =~ m{^distcc}) {
	    # distcc cruft
	    print STDERR "Ignoring distcc: $line\n" if $debug;
	} elsif (($msg) = $line =~ m{^Warning (\(.*)}i) {
	    # dtc warning
	    &add_record(\%warnings, $log, "dtc", "N/A", $msg);
	} elsif (($msg) = $line =~ m{^warning: (.*)}i) {
	    # modpost or relocs_check.pl warning
	    &add_record(\%warnings, $log, "warning", "N/A", $msg);
	} elsif ($debug) {
	    print STDERR "Unhandled error: $line\n" if ($line =~ /error/i);
	    print STDERR "Unhandled warning: $line\n" if ($line =~ /warn/i);
	}
    }
    close(LOG);
}

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
	    next if $#msgs1 == $#msgs2 and !$debug;
	    my $line = "$file: $msg: " . join(', ', @msgs1) . " => " .
		    join(', ', @msgs2) . "\n";
	    if ($#msgs1 < $#msgs2) {
		print "NEW  : $line" if $debug;
		push @regressions, $line;
	    } elsif ($#msgs1 > $#msgs2) {
		print "FIXED: $line" if $debug;
		push @improvements, $line;
	    } elsif ($debug) {
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

while (defined($ARGV[0])) {
	$option = $ARGV[0];
	last if not $option =~ /^-/;
	if ($option eq '-h' or $option eq '--help') {
		&usage();
	} elsif ($option eq '-d' or $option eq '--debug') {
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

$log1 = shift @ARGV;
$log2 = shift @ARGV;
&read_log($log1);
&read_log($log2);

print "\n*** ERRORS ***\n";
print_report(\%errors);
print "\n\n*** WARNINGS ***\n";
print_report(\%warnings);


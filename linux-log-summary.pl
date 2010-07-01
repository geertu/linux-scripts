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

Usage: $name [options] buildlogs...

Valid options:
	-h, --help	Display this help
	-v, --verbose	Enable verbose mode
EOF
}

sub set_common_prefix()
{
    my $s = shift;

    return if $s !~ m{^/};
    return if $s =~ m{^/opt};
    return if $s =~ m{^/tmp/};
    return if $s =~ m{^/usr};
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
    my $line = shift;
    my $id = shift;

    if (!exists($db->{$line})) {
	$db->{$line}{"cnt"} = 1;
    } else {
	$db->{$line}{"cnt"}++;
    }
    $db->{$line}{"logs"}{$log} = 1;
    &set_common_prefix($id);
}

sub read_log()
{
    my $log = shift;
    my ($line, $id, $msg);

    open(LOG, "<$log") or die "Cannot open $log";
    while ($line = <LOG>) {
	chomp($line);

	if (($id, $msg) = $line =~ m{(^.*):\s*error:\s*(.*$)}i) {
	    # compile error
	    &add_record(\%errors, $log, $line, $id);
	} elsif (($msg) = $line =~ m{error: (.*undefined!)}i) {
	    # link error: undefined symbol
	    &add_record(\%errors, $log, $line, "");
	} elsif (($id, $msg) = $line =~ m{^.*:\s*error in (.*);\s*(.*$)}i) {
	    # link error
	    &add_record(\%errors, $log, "$id: $msg", $id);
	} elsif (($id, $msg) = $line =~ m{(^.*):\s*warning:\s*(.*$)}i) {
	    # compile warning
	    &add_record(\%warnings, $log, $line, $id);
	} elsif (($msg) = $line =~ m{warning:\s(modpost:\s.*$)}i) {
	    # modpost warning
	    &add_record(\%warnings, $log, $msg, "modpost");
	} elsif ($line =~ m{^distcc}) {
	    # distcc cruft
	    print STDERR "Ignoring distcc: $line\n" if $debug;
	} elsif (($msg) = $line =~ m{^Warning (\(.*)}i) {
	    # dtc warning
	    &add_record(\%warnings, $log, $line, "dtc");
	} elsif (($msg) = $line =~ m{^warning: (.*)}i) {
	    # modpost or relocs_check.pl warning
	    &add_record(\%warnings, $log, $line, "");
	} elsif ($debug) {
	    print STDERR "Unhandled error: $line\n" if ($line =~ /error/i);
	    print STDERR "Unhandled warning: $line\n" if ($line =~ /warn/i);
	}
    }
    close(LOG);
}

sub print_record()
{
    my $record = shift;
    my $line = shift;
    my $type = shift;

    my $cnt = $record->{"cnt"};
    my @logs = keys %{$record->{"logs"}};
    my $logs = $#logs + 1;
    $line =~ s@^$common_prefix@@;
    print "$line: $cnt $type in $logs logs\n";
    print "\t@logs\n" if $verbose;
}

sub sort_records()
{
    my $a = shift;
    my $ra = shift;
    my $b = shift;
    my $rb = shift;

    my $logs1 = keys %{$ra->{"logs"}};
    my $logs2 = keys %{$rb->{"logs"}};

    return 1 if $logs1 < $logs2;
    return -1 if $logs1 > $logs2;
    return $a cmp $b;
}

sub sort_errors()
{
    return &sort_records($a, $errors{$a}, $b, $errors{$b});
}

sub sort_warnings()
{
    return &sort_records($a, $warnings{$a}, $b, $warnings{$b});
}

while (defined($ARGV[0])) {
	$option = $ARGV[0];
	last if not $option =~ /^-/;
	if ($option eq '-h' or $option eq '--help') {
		&usage();
	} elsif ($option eq '-d' or $option eq '--debug') {
		$debug = 1;
	} elsif ($option eq '-v' or $option eq '--verbose') {
		$verbose = 1;
	} elsif ($option eq '--') {
		shift @ARGV;
		last;
	} else {
		print STDERR "Unknown option $option\n";
		&usage();
	}
	shift @ARGV;
}

&usage if ($#ARGV < 0);

for $file (@ARGV) {
	&read_log($file);
}

print "\n*** ERRORS ***\n\n";
for $line (sort sort_errors (keys %errors)) {
    &print_record($errors{$line}, $line, "errors");
}

print "\n\n*** WARNINGS ***\n\n";
for $line (sort sort_warnings keys %warnings) {
    &print_record($warnings{$line}, $line, "warnings");
}

$errors = keys %errors;
$warnings = keys %warnings;
print "\n\n*** TOTAL: $errors errors and $warnings warnings ***\n\n";

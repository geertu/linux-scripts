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
    my $s = $_[0];

    # FIXME other cases
    return if $s =~ /^<stdin>/;
    if (defined($common_prefix)) {
	chop $common_prefix while ($s !~ /^\Q$common_prefix\E/);
    } else {
	$common_prefix = $s;
    }
}

sub add_record()
{
    my $db = $_[0];
    my $log = $_[1];
    my $line = $_[2];
    my $id = $_[3];

    if (!exists($db->{$line})) {
	my $record = {};
	$record->{"cnt"} = 1;
	$record->{"logs"} = [ $log ];
	$db->{$line} = $record;
    } else {
	$db->{$line}{"cnt"}++;
	if (@{$db->{$line}{"logs"}}[-1] ne $log) {
	    push @{$db->{$line}{"logs"}}, $log;
	}
    }
    &set_common_prefix($id);
}

sub read_log()
{
    my $log = $_[0];
    # FIXME more my variables

    open(LOG, "<$log") or die "Cannot open $log";
    while ($line = <LOG>) {
	chomp($line);

	if (($id, $msg) = $line =~ m{(^.*):\s*error:\s*(.*$)}) {
	    &add_record(\%errors, $log, $line, $id);
	} elsif (($id, $msg) = $line =~ m{(^.*):\s*warning:\s*(.*$)}) {
	    &add_record(\%warnings, $log, $line, $id);
	} elsif ($line =~ /error/i) {
	    # FIXME
	    print STDERR "Unhandled error: $line\n";
	} elsif ($line =~ /warn/i) {
	    # FIXME
	    print STDERR "Unhandled warning: $line\n";
	}
    }
    close(LOG);
}

sub print_record()
{
    my $record = $_[0];
    my $line = $_[1];
    my $type = $_[2];

    my $cnt = $record->{"cnt"};
    my @logs = @{$record->{"logs"}};
    my $logs = $#logs + 1;
    $line =~ s@^$common_prefix@@;
    print "$line: $cnt $type in $logs logs\n";
    print "\t@logs\n" if $verbose;
}

sub sort_records()
{
    my $a = $_[0];
    my $ra = $_[1];
    my $b = $_[2];
    my $rb = $_[3];

    my $logs1 = $#{$ra->{"logs"}};
    my $logs2 = $#{$rb->{"logs"}};

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

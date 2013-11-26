#!/usr/bin/perl -w

$baseurl = 'http://kisskb.ellerman.id.au/kisskb';
$branch = '9';	# FIXME Map from `linux-next' to `9'

$basedir = "branch$branch";
$htmlfile = "branch$branch.html";

system("wget $baseurl/branch/$branch/ -O $htmlfile");

mkdir($basedir);

open(IN, $htmlfile) or die "Cannot open $htmlfile";
while ($line = <IN>) {
    last if $line =~ /Disabled targets/;
    if ($line =~ m{/compiler/}) {
	$line = <IN>;
	($compiler) = $line =~ /[\s]+([a-z0-9_-]+)</;
	print "compiler = $compiler\n";
	mkdir("$basedir/$compiler");
    } elsif (($match) = $line =~ m{/target/[0-9]*/">([a-z0-9_-]+)</a}) {
	$target = $match;
	print "\ttarget = $target\n";
	undef $id;
    } elsif (($match) = $line =~ m{/buildresult/([0-9]+)/}) {
	if (!defined($id)) {
	    $id = $match;
	    print "\t\tid = $id\n";
	    system("wget $baseurl/buildresult/$id/log/ -O $basedir/$compiler/$target");
	}
    }
}
close(IN);

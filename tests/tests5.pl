#!/usr/bin/perl

use Art5;

$art5 = Art5->new();

$tests = 0;
$tests_ok = 0;

sub try {
	my $code	= shift;
	my $expected	= shift;

	my $result = $art5->process($code);

	if ($result eq $expected) {
		print "OK test: ", $code, "\n";
		$tests_ok++;
	}
	else {
		print "ERROR test: ", $code, "\n";
		print "\tExpected: '", $expected, "' ",
			"Got: '", $result, "'\n";
	}

	$tests++;
}

try('1<{}>2', '12');
try('1<{#}>2', '12');
try('1<{#this is a comment}>2', '12');
try('1<{#this is a comment "hello"}>2', '12');
try('1<{"hello"}>2', '1hello2');
try("1<{'hello'}>2", '1hello2');
try('1<{"hello\n"}>2', "1hello\n2");

print "\nTest result: ", $tests_ok, '/', $tests, ' (', ($tests_ok / $tests) * 100, "%)\n";

exit 0;


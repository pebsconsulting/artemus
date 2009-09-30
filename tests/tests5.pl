#!/usr/bin/perl

use Art5;

$art5 = Art5->new();

$tests = 0;
$tests_ok = 0;

$art5->{op}->{ary1} = sub { [ 'a', 'b', 'c' ]; };
$art5->{op}->{ary2} = sub { [ [1, 'a'], [2, 'b'], [3, 'b'], [4, 'c'] ]; };
$art5->{op}->{link} = sub { "<a href = '" . $art5->exec(shift) . "'>" . $art5->exec(shift) . "</a>"; };

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

try('<{}>', '');
try('1<{}>2', '12');
try('1<{#}>2', '12');
try('1<{#this is a comment}>2', '12');
try('1<{#this is a comment "hello"}>2', '12');
try("1<{#this is a comment\n'hello'}>2", '1hello2');
try('1<{"hello"}>2', '1hello2');
try("1<{'hello'}>2", '1hello2');
try('1<{"hello\n"}>2', "1hello\n2");
try('1<{%arch}>2', '1Unix2');
try('1<{3 4}>2', '1342');
try('1<{? 3 4}>2', '1342');
try('1<{3 4 5 6}>2', '134562');
try('1<{? 3 4 5 6}>2', '134562');
try('1<{add 3 4}>2', '172');
try('1<{foreach ary1}>2', '1abc2');
try('1<{foreach ary1 $0}>2', '1abc2');
try('1<{foreach ary1 {? "<" $0 ">"}>2', '1<a><b><c>2');
try('1<{foreach ary1 $0 ", "}>2', '1a, b, c2');
try('1<{foreach ary2}>2', '112342');
try('1<{foreach ary2 $0}>2', '112342');
try('1<{foreach ary2 $1}>2', '1abbc2');
try('1<{foreach ary2 $0 ", "}>2', '11, 2, 3, 42');
try('1<{foreach ary2 $1 ", "}>2', '1a, b, b, c2');
try('1<{foreach ary2 $0 ", " {? "[" $1 "]"}}>2', '1[a]1, [b]2, 3, [c]42');
try('1<{if {eq 1 2} "equal"}>2', '12');
try('1<{if {eq 1 1} "equal"}>2', '1equal2');
try('1<{if {eq 1 2} "equal" "different"}>2', '1different2');
try('1<{if {eq 1 1} "equal" "different"}>2', '1equal2');
try('1<{if {eq 1 2} {"equal"}}>2', '12');
try('1<{if {eq 1 1} {"equal"}}>2', '1equal2');
try('1<{if {eq 1 2} {"equal"} {"different"}}>2', '1different2');
try('1<{if {eq 1 1} {"equal"} "different"}}>2', '1equal2');
try('1<{link}>2', "1<a href = ''></a>2");
try('1<{link "http://url"}>2', "1<a href = 'http://url'></a>2");
try('1<{link "http://url" "label"}>2', "1<a href = 'http://url'>label</a>2");
try('1<{= "RESULT" 1000}>2<{RESULT}>3', '1210003');

print "\nTest result: ", $tests_ok, '/', $tests, ' (', ($tests_ok / $tests) * 100, "%)\n";

exit 0;


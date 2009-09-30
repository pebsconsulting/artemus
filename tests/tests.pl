#!/usr/bin/perl

use Art5;

my $a = Art5->new();

#my $src = join('', <>);

#print $a->process($src);

# <a href = http://host?t=<{$0}>;offset=0><{or $1 "Main index"}></a>

my $url = [ '?',
		[ '"', '<a href = http://host/?t=' ],
		[ '$', 0 ],
		[ '"', ';offset='],
		[ 'or',
			[ '$', 2 ],
			[ '"', 0 ],
		],
		[ '"', '>'],
		[ 'or',
			[ '$', 1 ],
			[ '"', 'Main index' ],
		],
		[ '"', '</a>' ]
	];

$a->{op}->{url} = $url;

# navigator
# <span class = 'prev'><{
#	if $2
#	{?
#		"<a href = "
#		{url "INDEX" "topic" $0 "offset" {sub $2 $1}}
#		">&lt;&lt;</a>"
#	}
#}></span>

# <html>\n<{url 'LOGIN' 'Login page'}>\n<{url 'INDEX'}></html>

my $p = [ '?',
		[ '"', "<html>\n" ],
		[ 'url', [ '"', 'LOGIN'], ['"', 'Login page'], ['"', 10 ]],
		[ '"', "\n" ],
		[ 'url', [ '"', 'INDEX'] ],
		[ '"', "\n</html>" ]
	];

print $a->exec($p), "\n";

my $c;
$c = $a->compile("Leading <{%arch}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{? 'Arch: ' %arch}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{mul {add 10 20} 1000}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{? {= 'TEST' 'here'} { TEST }}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{if {eq 1 2} 'Equal' 'Different'}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{if {eq 1 1} 'Equal' 'Different'}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{if {eq 1 2} {'Equal'} {'Different'}}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{if {eq 1 1} {'Equal'} {'Different'}}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{url 'LOGIN' 'Login page'}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{random 1 2 3 4 5 6}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{env}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{foreach env}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{foreach env \$0}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{foreach env \$0 ', '}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{foreach env {? \$0 '=' {env \$0}} ', '}> Trailing");
print $a->exec($c), "\n";
$c = $a->compile("Leading <{1 2 3}> Trailing");
print $a->exec($c), "\n";

exit 0;

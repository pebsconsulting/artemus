#!/usr/bin/perl

use Artemus;

@unresolved=();

%vars=(
	"link"	=>	'<a href="$0">$1</a>',
	"autolink" =>	'{-link|{-http|$0}|$0}',
	"http"	=>	'http://$0'
	);

$ah=new Artemus(	"vars"	=> \%vars,
			"unresolved" => \@unresolved,
		);

$t=$ah->armor("{-template}");
print "$t\n";

$t=$ah->params('Este $0 parece un $1',"chirifú","guarripé");
print "$t\n";

$t=$ah->process('{-autolink|192.168.1.1} {-localtime} {-\VERSION}');
print "$t\n";

#!/usr/bin/perl

use Artemus5;

my $artemus = Artemus5->new( path => [ '.' ]);

my $stream = $artemus->_compile(join('', <>));
print $artemus->execute($stream, '1st arg', '2nd arg');

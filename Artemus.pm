package Artemus;

use locale;
use strict;
use warnings;

use Artemus4;

$Artemus::VERSION = $Artemus4::VERSION;

sub new {
	my $class	= shift;
	my %args	= @_;

	my $self;

	if (!$args{version}) {
		$args{version} = 4;
	}

	if ($args{version} == 4) {
		$self = Artemus4->new(%args);
	}

	return $self;
}

1;
__END__

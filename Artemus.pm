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
=pod

=head1 NAME

Artemus - Template Toolkit

=head1 DESCRIPTION

This is just a frontend for the two concurrent Artemus versions. The
C<version> argument to C<new()> makes possible to select from version
4 or 5. The rest of arguments are version-dependent.

Please pick further documentation from inside the following modules:

=head2 Artemus4

L<Artemus4>, the stable 4.x version.

=head2 Artemus5

L<Artemus5>, the faster, compiled 5.x version.

=head1 AUTHOR

Angel Ortega angel@triptico.com

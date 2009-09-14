#####################################################################
#
#   Artemus - Template Toolkit version 5
#
#   Copyright (C) 2000/2009 Angel Ortega <angel@triptico.com>
#
#   This program is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either version 2
#   of the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#   http://triptico.com
#
#####################################################################

use locale;

package Artemus5;

use strict;
use warnings;

$Artemus5::VERSION = '5.0.0-dev';

sub code {
	my $self	= shift;
	my $op		= shift;

	if (!exists($self->{op}->{$op})) {
		# try to load and compile from the path
		# ...

		# fail otherwise
		$self->{op}->{$op} = "UNDEF{$op}";
	}

	return $self->{op}->{$op};
}

sub exec {
	my $self	= shift;
	my $prg		= shift;
	my @args	= @_;

	if (ref($prg) eq 'ARRAY') {
		# stream of Artemus5 code
		my @stream = @{$prg};

		# pick opcode
		my $op = shift(@stream);

		# pick code
		my $c = $self->code($op);

		if (!ref($c)) {
			# direct value
			return $c;
		}

		# map arguments ($0, $1...)
		@stream = map {
			my $v = $_;

			if ($v =~ /^\$(\d+)$/) {
				$v = $args[$1] || '';
			}

			$_ = $v;
		} @stream;

		if (ref($c) eq 'ARRAY') {
			# another Artemus5 stream
			return $self->exec($c, @stream);
		}
		elsif (ref($c) eq 'CODE') {
			# function call
			return $c->(@stream);
		}
	}
	else {
		if ($prg =~ /^%(.+)$/) {
			# variable from external hash
			#(for example, CGI variables)
			return $self->{xh}->{$1};
		}
		else {
			# direct value
			return $prg;
		}
	}

	return '';
}

sub init {
	my $self	= shift;

	$self->{op}->{VERSION} = $Artemus5::VERSION;

	$self->{op}->{VERSION_STR} = [
		'?', 'Artemus ', [ 'VERSION' ]
	];

	$self->{op}->{'?'} = sub {
		return join('', map { $self->exec($_); } @_);
	};

	$self->{op}->{'='} = sub {
		$self->{op}->{$self->exec($_[0])} =
			$self->exec($_[1]);
		return '';
	};

	$self->{op}->{env} = sub {
		return $ENV{$self->exec($_[0])};
	};

	$self->{xh}->{arch} = 'Unix';

	return $self;
}


sub new {
	my $class	= shift;

	my $self = bless { @_ }, $class;

	$self->{path} ||= [];

	return $self->init();
}

1;
__END__

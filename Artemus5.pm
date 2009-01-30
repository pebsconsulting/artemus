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

sub tokenize {
	my $source	= shift;

	return grep { $_ } split(/(\{-|\||\})/, $source);
}


sub c2 {
	my $tokens	= shift;

	# pick template
	my $t = shift(@{$tokens});
	my @arg = ();

	while (@{$tokens}) {
		my $token = shift(@{$tokens});

		if ($token eq '}') {
			last;
		}
		elsif ($token eq '{-') {
			push(@arg, c2($tokens));
		}
		elsif ($token eq '|') {
			push(@arg, c1($tokens));
		}
	}

	return { t => $t, arg => [ @arg ] };
}


sub c1 {
	my $tokens	= shift;

	my @stream = ();

	while (@{$tokens}) {
		my $token = $tokens->[0];

		if ($token eq '|' || $token eq '}') {
			last;
		}

		shift(@{$tokens});

		if ($token eq '{-') {
			push(@stream, c2($tokens));
		}
		else {
			push(@stream, $token);
		}
	}

	return [ @stream ];
}


sub _compile {
	my $self	= shift;
	my $source	= shift;

	my @tokens = tokenize($source);
	return c1(\@tokens);
}


sub load_template {
	my $self	= shift;
	my $template	= shift;

	foreach my $p (@{$self->{path}}) {
		if (open F, $p . '/' . $template) {
			my $ret = '';

			while (<F>) {
				unless (/^=/ .. /^=cut/) {
					$ret .= $_;
				}
			}

			close F;

			return $ret;
		}
	}

	return undef;
}


sub get_template {
	my $self        = shift;
	my $template    = shift;

	my $ret = undef;

	if (! ($ret = $self->{funcs}->{$template}) &&
	    ! ($ret = $self->{compiled}->{$template})) {

		my $src = ($self->{vars}->{$template} ||
			$self->load_template($template));

		if ($src && ($ret = $self->_compile($src))) {
			$self->{compiled}->{$template} = $ret;
		}
	}

	return $ret;
}


sub as_text {
	my $self	= shift;
	my $val		= shift;

	if (ref($val) eq 'ARRAY') {
		$val = join(':', map
			{ ref($_) ? join(',', @{$_}) : $_ } @{$val});
	}

	return $val;
}


sub as_list {
	my $self	= shift;
	my $val		= shift;

	my @ret = ();

	if (ref($val) eq 'ARRAY') {
		@ret = @{$val};
	}
	else {
		@ret = map { [ split(/\s*,\s*/, $_) ] } split(/\s*:\s*/, $val);
	}

	return @ret;
}


sub params {
	my $self	= shift;
	my $str		= shift;

	for (my $n = 0; $n < scalar(@_); $n++) {
		$str =~ s/\$$n/$self->execute($_[$n])/ge;
	}

	return $str;
}


sub execute {
	my $self	= shift;
	my $stream	= shift;

	if (!$stream) {
		return '';
	}

	my @ret = ();

	my $r = ref($stream);

	if (!$r) {
		# scalar; return as is
		$stream = $self->params($stream, @_);
		push(@ret, $stream);
	}
	elsif ($r eq 'ARRAY') {
		# stream of values
		foreach my $i (@{$stream}) {
			push(@ret, $self->execute($i, @_));
		}
	}
	elsif ($r eq 'HASH') {
		# template call
		my $t = $stream->{t};

		my $c = $self->get_template($stream->{t});

		if (defined($c)) {
			push(@ret, $self->execute($c, @{$stream->{arg}}));
		}
		else {
			push(@ret, $t);
		}
	}
	elsif ($r eq 'CODE') {
		# function call
		push(@ret, $stream->(@_));
	}

	if (scalar(@ret) == 1) {
		return $ret[0];
	}
	else {
		return join('', map { $self->as_text($_) } @ret);
	}
}


sub init {
	my $self	= shift;

	$self->{funcs}->{env} = sub {
		my $var = $self->execute(shift);

		if ($var) {
			return $ENV{$var};
		}
		else {
			return [ map { [ $_ ] } keys(%ENV) ];
		}
	};

	$self->{funcs}->{set} = sub {
		my $name = $self->execute(shift);
		my $value = $self->execute(shift);

		$self->{vars}->{$name} = $value;

		return '';
	};

	$self->{funcs}->{if} = sub {
		my $cond = $self->execute(shift);
		my $if = shift;
		my $unless = shift;

		my $ret = '';

		if ($cond) {
			$ret = $self->execute($if);
		}
		elsif ($unless) {
			$ret = $self->execute($unless);
		}

		return $ret;
	};

	$self->{funcs}->{eq} = sub {
		$self->execute(shift) eq $self->execute(shift) ? 1 : 0;
	};
	$self->{funcs}->{gt} = sub {
		($self->execute(shift) || 0) > ($self->execute(shift) || 0) ? 1 : 0;
	};
	$self->{funcs}->{lt} = sub {
		($self->execute(shift) || 0) < ($self->execute(shift) || 0) ? 1 : 0;
	};

	$self->{funcs}->{and} = sub {
		($self->execute(shift) && $self->execute(shift)) || '';
	};
	$self->{funcs}->{or} = sub {
		($self->execute(shift) || $self->execute(shift)) || '';
	};
	$self->{funcs}->{not} = sub {
		$self->execute(shift) ? 0 : 1;
	};

	$self->{funcs}->{add} = sub {
		($self->execute(shift) || 0) + ($self->execute(shift) || 0);
	};
	$self->{funcs}->{sub} = sub {
		($self->execute(shift) || 0) - ($self->execute(shift) || 0);
	};

	$self->{funcs}->{random} = sub {
		$self->execute($_[rand(scalar(@_))]);
	};

	$self->{funcs}->{foreach} = sub {
		my $list	= $self->execute(shift);
		my $block	= shift;
		my $sep		= $self->execute(shift);

		my @ret = ();

		foreach my $e ($self->as_list($list)) {

			my $n = 1;
			foreach my $v (@{$e}) {
				$self->{vars}->{$n++} = $v;
			}

			push(@ret, $self->execute($block));
		}

		return join($sep, @ret);
	};

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

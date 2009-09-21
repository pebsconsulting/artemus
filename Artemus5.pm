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

sub compile_c {
	my $self	= shift;
	my $seq		= shift;
	my @ret		= ();

	# delete leading blanks and a possible brace
	$$seq =~ s/^\s*\{?\s*//;

	while ($$seq) {
		if ($$seq =~ s/^"(([^"\\]*(\\.[^"\\]*)*))"\s*//) {
			# double quoted string
			my $str = $1;

			# replace usual escaped characters
			$str =~ s/\\n/\n/g;
			$str =~ s/\\r/\r/g;
			$str =~ s/\\t/\t/g;
			$str =~ s/\\"/\"/g;
			$str =~ s/\\\\/\\/g;

			push(@ret, [ '"', $str ]);
		}
		elsif ($$seq =~ s/^'(([^'\\]*(\\.[^'\\]*)*))'\s*//) {
			# single quoted string
			my $str = $1;

			$str =~ s/\\'/\'/g;
			$str =~ s/\\\\/\\/g;

			push(@ret, [ '"', $str ]);
		}
		elsif ($$seq =~ s/^(\d+(\.\d+)?)\s*//) {
			# number
			push(@ret, [ '"', $1 ]);
		}
		elsif ($$seq =~ /^\{\s*/) {
			# another code sequence
			push(@ret, $self->compile_c($seq));
		}
		elsif ($$seq =~ s/^\}\s*//) {
			# end of sequence
			last;
		}
		elsif ($$seq =~ s/^%([^\s\{\}]+)\s*//) {
			# external hash value
			push(@ret, [ '%', $1 ]);
		}
		elsif ($$seq =~ s/^\$(\d+)\s*//) {
			# argument
			push(@ret, [ '$', $1 ]);
		}
		elsif ($$seq =~ s/^([^\s\{\}]+)\s*//) {
			# opcode

			# nothing yet? operator call
			if (scalar(@ret) == 0) {
				push(@ret, $1);
			}
			else {
				push(@ret, [ $1 ]);
			}
		}
		else {
			die "Syntax error near $$seq";
		}
	}

	# is the first thing in the sequence an array
	# (instruction) and not a string (opcode)?
	if (ref($ret[0]) eq 'ARRAY') {
		# only one instruction? return as is
		if (scalar(@ret) == 1) {
			return $ret[0];
		}

		# otherwise, prepend a '?' (joiner)
		unshift(@ret, '?');
	}

	return [ @ret ];
}


sub compile {
	my $self	= shift;
	my $str		= shift;

	# was this code already compiled?
	if (exists($self->{pc}->{$str})) {
		return $self->{pc}->{$str};
	}

	# joiner opcode
	my @ret = ( '?' );

	# split by the Artemus5 marks
	my @stream = split(/(<\{|\}>)/, $str);

	# alternate between literal strings and Artemus5 code
	while (@stream) {
		my $p = shift(@stream);

		if ($p eq '<{') {
			$p = '{' . shift(@stream) . '}';
			push(@ret, $self->compile_c(\$p));
			shift(@stream);
		}
		else {
			push(@ret, [ '"', $p ]);
		}
	}

	my $ret = [ @ret ];

	return $self->{pc}->{$str} = $ret;
}


sub code {
	my $self	= shift;
	my $op		= shift;

	if (!exists($self->{op}->{$op})) {
		my $src = undef;

		# does a loader_func() exist?
		if (ref($self->{loader_func}) eq 'CODE') {
			$src = $self->{loader_func}->{$op};
		}

		if (!defined($src)) {
			# try to resolve by loading
			# a source file from the path
			foreach my $p (@{$self->{path}}) {
				if (open(F, $p . '/' . $op)) {
					$src = join('', <F>);
					close F;

					last;
				}
			}
		}

		# compile if available
		if (defined($src)) {
			$self->{op}->{$op} = $self->compile($src);
		}
	}

	return $self->{op}->{$op};
}


sub exec {
	my $self	= shift;
	my $prg		= shift;
	my $ret;

	# stream of Artemus5 code
	my @stream = @{$prg};

	# pick opcode
	my $op = shift(@stream);

	# pick code
	my $c = $self->code($op);

	if (ref($c) eq 'CODE') {
		$ret = $c->(@stream);
	}
	elsif (ref($c) eq 'ARRAY') {
		# push the arguments to the stack
		push(@{$self->{stack}},
			[ map { $self->exec($_); }
				@stream ]);

		$ret = $self->exec($c);

		# drop stack
		pop(@{$self->{stack}});
	}
	else {
		die "Opcode not found: $op";
	}

	if (!defined($ret)) {
		$ret = '';
	}

	return $ret;
}


sub exec0 {
	my $self	= shift;

	return $self->exec(@_) || 0;
}


sub init {
	my $self	= shift;

	$self->{stack} = [ [] ];

	$self->{op}->{VERSION} = [ '"', $Artemus5::VERSION ];

	$self->{op}->{VERSION_STR} = [
		'?', 'Artemus ', [ 'VERSION' ]
	];

	# literal
	$self->{op}->{'"'} = sub {
		return $_[0];
	};

	# argument
	$self->{op}->{'$'} = sub {
		return $self->{stack}->[-1]->[$_[0]];
	};

	# external hash (e.g. CGI variables)
	$self->{op}->{'%'} = sub {
		return $self->{xh}->{$_[0]};
	};

	# joiner
	$self->{op}->{'?'} = sub {
		return join('', map { $self->exec($_); } @_);
	};

	# assignation
	$self->{op}->{'='} = sub {
		$self->{op}->{$self->exec($_[0])} =
			[ '"', $self->exec($_[1]) ];

		return '';
	};

	$self->{op}->{eq} = sub {
		$self->exec($_[0]) eq
			$self->exec($_[1]) ? 1 : 0;
	};
	$self->{op}->{ne} = sub {
		$self->exec($_[0]) ne
			$self->exec($_[1]) ? 1 : 0;
	};

	$self->{op}->{and} = sub {
		$self->exec($_[0]) && $self->exec($_[1]);
	};
	$self->{op}->{or} = sub {
		$self->exec($_[0]) || $self->exec($_[1]);
	};
	$self->{op}->{not} = sub {
		$self->exec($_[0]) ? 0 : 1;
	};

	$self->{op}->{if} = sub {
		my $ret = '';

		if ($self->exec($_[0])) {
			$ret = $self->exec($_[1]);
		}
		elsif (scalar(@_) == 3) {
			$ret = $self->exec($_[2]);
		}

		$ret;
	};

	$self->{op}->{add} = sub {
		return $self->exec0($_[0]) + $self->exec0($_[1]);
	};
	$self->{op}->{sub} = sub {
		return $self->exec0($_[0]) - $self->exec0($_[1]);
	};
	$self->{op}->{mul} = sub {
		return $self->exec0($_[0]) * $self->exec0($_[1]);
	};
	$self->{op}->{div} = sub {
		return $self->exec0($_[0]) / $self->exec0($_[1]);
	};

	$self->{op}->{gt} = sub {
		return $self->exec0($_[0]) > $self->exec0($_[1]);
	};
	$self->{op}->{lt} = sub {
		return $self->exec0($_[0]) < $self->exec0($_[1]);
	};
	$self->{op}->{random} = sub {
		return $self->exec($_[rand(scalar(@_))]);
	};

	$self->{op}->{env} = sub {
		# no arguments? return keys as an arrayref
		if (scalar(@_) == 0) {
			return [ keys(%ENV) ];
		}

		return $ENV{$self->exec($_[0])};
	};

	$self->{op}->{foreach} = sub {
		my $list	= shift;
		my $code	= shift || [ '$', 0 ];
		my $sep		= shift || [ '"', '' ];
		my $header	= shift || [ '"', '' ];

		my @ret = ();
		my $ph = '';

		# create a stack for the elements
		push(@{$self->{stack}}, []);

		foreach my $e (@{$self->exec($list)}) {
			# store the element in the stack
			$self->{stack}->[-1] =
				ref($e) ? $e : [ $e ];

			# execute the header code
			my $o = $self->exec($header);

			# if it's different from previous header,
			# strip from output; otherwise, remember
			# for next time
			if ($ph eq $o) {
				$o = '';
			}
			else {
				$ph = $o;
			}

			# execute the body code
			$o .= $self->exec($code);

			push(@ret, $o);
		}

		# destroy last stack
		pop(@{$self->{stack}});

		return join($self->exec($sep), @ret);
	};

	$self->{xh}->{arch} = 'Unix';

	return $self;
}


sub process {
	my $self	= shift;
	my $src		= shift;

	my $c = $self->compile($src);

	return $self->exec($c, @_);
}


sub new {
	my $class	= shift;

	my $self = bless { @_ }, $class;

	$self->{path} ||= [];

	return $self->init();
}

1;
__END__

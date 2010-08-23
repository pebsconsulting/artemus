#####################################################################
#
#   Artemus - Template Toolkit version 5
#
#   Copyright (C) 2000/2010 Angel Ortega <angel@triptico.com>
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

package Art5;

use strict;
use warnings;
use Carp;

$Art5::VERSION = '5.0.1-dev';

sub parse {
	my $self	= shift;
	my $seq		= shift;
	my @ret		= ();

	# delete leading blanks and a possible brace
	$$seq =~ s/^\s*\{?\s*//;

	while ($$seq) {
		# delete comments
		if ($$seq =~ s/^#.*$//gm) {
			$$seq =~ s/^\s+//;
		}
		elsif ($$seq =~ s/^(@?)"(([^"\\]*(\\.[^"\\]*)*))"\s*//) {
			# double quoted string
			my $op	= $1 || '"';
			my $str	= $2;

			# replace usual escaped characters
			$str =~ s/\\n/\n/g;
			$str =~ s/\\r/\r/g;
			$str =~ s/\\t/\t/g;
			$str =~ s/\\"/\"/g;
			$str =~ s/\\\\/\\/g;

			push(@ret, [ $op, $str ]);
		}
		elsif ($$seq =~ s/^(@?)'(([^'\\]*(\\.[^'\\]*)*))'\s*//) {
			# single quoted string
			my $op	= $1 || '"';
			my $str	= $2;

			$str =~ s/\\'/\'/g;
			$str =~ s/\\\\/\\/g;

			push(@ret, [ $op, $str ]);
		}
		elsif ($$seq =~ s/^(\d+(\.\d+)?)\s*//) {
			# number
			push(@ret, [ '"', $1 ]);
		}
		elsif ($$seq =~ /^\{\s*/) {
			# another code sequence
			push(@ret, $self->parse($seq));
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
			croak "Artemus5 syntax error near '$$seq'";
		}
	}

	# no program? return a NOP */
	if (!@ret) {
		return [ '"', '' ];
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
			push(@ret, $self->parse(\$p));
			shift(@stream);
		}
		elsif ($p) {
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

		# filter opcode to only allow
		# characters valid in file names
		$op =~ s/[^\w\d_-]//g;

		# does a loader_func() exist?
		if (ref($self->{loader_func}) eq 'CODE') {
			$src = $self->{loader_func}->($op);
		}

		if (!defined($src)) {
			# try to resolve by loading
			# a source file from the path
			foreach my $p (@{$self->{path}}) {
				my $fp = $p . '/' . $op;

				# does a precompiled script already exist?
				if ($self->{cache} && -f $fp) {
					my $cp = $self->{cache} . $op;

					if (-f $cp && -M $cp < -M $fp) {
						# it does and it's fresh; import wildly
						$self->{op}->{$op} = eval "require '$cp'";
						last;
					}
				}

				# load the source
				if (open(F, $fp)) {
					$src = join('', <F>);
					close F;

					last;
				}
			}
		}

		# compile if available
		if (defined($src)) {
			$self->{op}->{$op} = $self->compile($src);

			# if there is a cache directory, save the compiled code
			if ($self->{cache} and open(F, '>' . $self->{cache} . $op)) {
				use Data::Dumper;

				print F Dumper($self->{op}->{$op});
				close F;
			}
		}
	}

	return $self->{op}->{$op};
}


sub exec {
	my $self	= shift;
	my $prg		= shift;
	my $ret;

	# aborted or empty? do nothing more
	if (!ref($prg) || $self->{abort}) {
		return '';
	}

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
		croak "Artemus5 opcode not found: $op";
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

	$self->{op}->{VERSION} = [ '"', $Art5::VERSION ];

	$self->{op}->{VERSION_STR} = [
		'?', [ '"', 'Artemus ' ], [ 'VERSION' ]
	];

	# literal
	$self->{op}->{'"'} = sub {
		return $_[0];
	};

	# translateable literal
	$self->{op}->{'@'} = sub {
		return $self->{t}->{$_[0]} || $_[0];
	};

	# argument
	$self->{op}->{'$'} = sub {
		return $self->{stack}->[-1]->[$_[0]];
	};

	# external hash (e.g. CGI variables)
	$self->{op}->{'%'} = sub {
		my $var = shift;

		return $var eq '%' ? $self->{xh} : $self->{xh}->{$var};
	};

	# joiner
	$self->{op}->{'?'} = sub {
		if (scalar(@_) == 1) {
			return $self->exec($_[0]);
		}

		return join('', map { $self->exec($_); } @_);
	};

	# array
	$self->{op}->{'&'} = sub {
		return [ map { $self->exec($_); } @_ ];
	};

	# assignation
	$self->{op}->{'='} = sub {
		$self->{op}->{$self->exec($_[0])} =
			[ '"', $self->exec($_[1]) ];

		return '';
	};

	# list of translation pairs
	$self->{op}->{'T'} = sub {
		while (scalar(@_) > 1) {
			my $k = $self->exec(shift);
			my $v = $self->exec(shift);

			$self->{t}->{$k} = $v;
		}

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

		foreach my $e (@{$self->exec($list)}) {
			# create a stack for the elements
			# and store the element in the stack
			push(@{$self->{stack}}, ref($e) ? $e : [ $e ]);

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

			# destroy last stack
			pop(@{$self->{stack}});
		}

		return join($self->exec($sep), @ret);
	};

	$self->{op}->{case} = sub {
		my $value	= $self->exec(shift);
		my $oth;

		# if args are odd, the last one is
		# the 'otherwise' case
		if (scalar(@_) % 2) {
			$oth = pop(@_);
		}

		# now treat the rest of arguments as
		# pairs of case / result
		while (@_) {
			my $case =	$self->exec(shift);
			my $res = 	shift;

			if ($value eq $case) {
				return $self->exec($res);
			}
		}

		return defined($oth) ? $self->exec($oth) : '';
	};

	$self->{op}->{seq} = sub {
		my $from	= $self->exec0(shift);
		my $to		= $self->exec0(shift);

		return [ $from .. $to ];
	};

	$self->{op}->{sort} = sub {
		my $list	= $self->exec(shift);
		my $code	= shift || [ '$', 0 ];

		# create a stack for the elements
		push(@{$self->{stack}}, []);

		my $ret = [ sort {
			$self->{stack}->[-1] = ref($a) ? $a : [ $a ];
			my $va = $self->exec($code);

			$self->{stack}->[-1] = ref($b) ? $b : [ $b ];
			my $vb = $self->exec($code);

			$va cmp $vb;
		} @{$list} ];

		# destroy last stack
		pop(@{$self->{stack}});

		return $ret;
	};

	$self->{op}->{reverse} = sub {
		return [ reverse @{$self->exec(shift)} ];
	};

	$self->{op}->{size} = sub { return scalar @{$self->exec($_[0])} };

	$self->{op}->{split} = sub {
		if (scalar(@_) == 3) {
			return [ map { [ split($self->exec($_[1]), $_) ] }
					split($self->exec($_[0]), $self->exec($_[2]))
				];
		}
		return [ split($self->exec($_[0]), $self->exec($_[1])) ];
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

	if ($self->{cache}) {
		mkdir $self->{cache};
	}

	return $self->init();
}

1;
__END__
=pod

=head1 NAME

Art5 - Template Toolkit

=head1 SYNOPSIS

 use Art5;
 
 # creates a new object
 my $art5 = Art5->new(path => \@path_to_templates);
 
 # compiles and executes a string of Art5 code
 my $r = $art5->process($source_code);

=head1 DESCRIPTION

Artemus is a template toolkit. It filters text files, parsing, compiling
and executing code surrounded by special marks (leaving the rest
untouched) and concatenating everything as output. Its main purpose is
to filter HTML files, but it can be used for any scripting need related
to text filtering and substitution.

The main purpose of the Art5 API is to add your own functions to the
Art5 machine to make them part of the programming language. For more
information on the Art5 Templating Language, please see the included
L<art5_overview> document.

This can be done by adding code to the C<op> component of the Art5
object. For example, this is a way to add a C<localtime> function to
Art5:

 $art5->{op}->{localtime} = sub { return localtime(); };

Art5 functions can also accept arguments. They arrive as code streams
that must be executed before use. For example, this is a function that
accept two numbers and returns the average:

 $art5->{op}->{avg} = sub {
          my $v1 = shift;
          my $v2 = shift;
 
          return ($art5->exec($v1) + $art5->exec($v2)) / 2;
 };

Art5 functions always have to return something. If you have nothing to
return, use an empty string. If an array must be returned (for example,
to be feed to C<foreach>, return a reference to it (not the array
itself).

The external hash can similarly accessed by tweaking the C<xh>
component. In this example, the running program process id will be
accesible as %pid:

 $art5->{xh}->{pid} = $!;

=head1 FUNCTIONS AND METHODS

=cut

=head2 new

 $art5 = Art5->new(
    [ path        => \@directories, ]
    [ cache       => $directory, ]
    [ loader_func => \&function, ]
 );

Creates a new Art5 object. The object creation accepts the following
arguments:

=head3 path

A reference to a list of directories where templates are to be found.

=head3 cache

A directory path where compiled templates are to be cached. These compiled
templates are raw Data::Dumper output of the compiled stream, and are
loaded back with simple C<eval()>, so take B<extreme care>.

=head3 loader_func

A pointer to a function to be called whenever a new template is queried
by the underlying system. This function should return the content of a
template or undef if not found. This mechanism is used to have an external
storage for templates (as in a SQL Database, for example). Take note that
templates retrived this way cannot be cached (this defect will eventually
be solved).

This function is called before any search in the L<path>.

=head2 process

 my $ret_val = $art->process($art5_code);

Compiles a string of Art5 code, executes it and returns the exit
value.

=head2 compile

 my $opcode_stream = $art5->compile($art5_code);

Reads a string of Art5 code and returns a compiled stream.

=head2 exec

 my $ret_val = $art5->exec($opcode_stream);

Executes a compiled stream (returned by C<compile()>) and returns
the exit value.

=head1 AUTHOR

Angel Ortega angel@triptico.com


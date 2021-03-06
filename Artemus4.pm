#####################################################################
#
#   Artemus - Template Toolkit version 4
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

package Artemus4;

use strict;
use warnings;

$Artemus4::VERSION = '4.1.3-dev';

sub armor {
	my $self	= shift;
	my $str		= shift;

	if ($str) {
		$str =~ s/{/\&#123;/g;
		$str =~ s/\|/\&#124;/g;
		$str =~ s/}/\&#125;/g;
		$str =~ s/\$/\&#36;/g;
	#	$str =~ s/=/\&#61;/g;
	}

	return $str;
}


sub unarmor {
	my $self	= shift;
	my $str		= shift;

	if ($str) {
		$str =~ s/\&#123;/{/g;
		$str =~ s/\&#124;/\|/g;
		$str =~ s/\&#125;/}/g;
		$str =~ s/\&#36;/\$/g;
	#	$str =~ s/\&#61;/=/g;
	}

	return $str;
}


sub strip {
	my ($ah, $t) = @_;

	$t =~ s/{-([-\\\w_ \.]+)[^{}]*}/$1/g;

	return $t;
}


sub params {
	my $self	= shift;
	my $str		= shift;

	my $n = 0;
	foreach my $a (@_) {
		$a ||= '';
		$str =~ s/(^|[^\\])\$$n/$1$a/g;
		$n++;
	}

	$str =~ s/(^|[^\\])\$\d+/$1/g;

	return $str;
}


sub process {
	my ($ah, $data) = @_;

	# not aborted by now
	${$ah->{'abort-flag'}} = 0;

	# no unresolved templates by now
	@{$ah->{'unresolved'}} = ();

	# reset calling stack
	@{$ah->{call_stack}} = ();

	# surround with \BEGIN and \END
	$data = $ah->{'vars'}->{'\BEGIN'} . $data . $ah->{'vars'}->{'\END'};

	# really do it, recursively
	$data = $ah->_process_do($data, 0);

	# finally, convert end of lines if necessary
	if ($ah->{'use-cr-lf'}) {
		$data =~ s/\n/\r\n/g;
	}

	# strip comments
	$data =~ s/{%[^}]+}//g;

	return $data;
}


sub _process_do {
	my ($ah, $data, $level, $template_name) = @_;
	my ($cache_time);

	# test if the template includes cache info
	if ($data =~ s/{-\\CACHE\W([^}]*)}//) {
		if ($template_name and $ah->{'cache-path'}) {
			$cache_time = $1;

			# convert strange chars to :
			$template_name =~ s/[^\w\d_]/:/g;

			my ($f) = "$ah->{'cache-path'}/$template_name";

			if (-r $f and -M $f < $cache_time) {
				open F, $f;
				flock F, 1;
				$data = join('', <F>);
				close F;

				return $data;
			}
		}
	}

	# strip POD documentation, if any
	if ($data =~ /=cut/ and not $ah->{'contains-pod'}) {
		my (@d);

		foreach (split("\n", $data)) {
			unless (/^=/ .. /^=cut/) {
				push(@d, $_);
			}
		}

		$data = join("\n", @d);
	}

	# strips HTML comments
	if ($ah->{'strip-html-comments'}) {
		$data =~ s/<!--.*?-->//gs;
	}

	# if defined, substitute the paragraphs
	# with the paragraph separator
	if ($ah->{'paragraph-separator'}) {
		$data =~ s/\n\n/\n$ah->{'paragraph-separator'}\n/g;
	}

	# inverse substitutions
	# (disabled until it works)
#	 while (my ($i, $v) = each(%{$ah->{'inv-vars'}})) {
#		 $data =~ s/\b$i\b/$v/g;
#	 }

	# main function, variable and include substitutions
	while ($data =~ /{-([^{}\\]*(\\.[^{}\\]*)*)}/s) {
		my ($found) = $1;

		# take key and params
		my ($key, $params) = ($found =~ /^([-\\\w_]+)\|?(.*)$/s);

		# replace escaped chars
		$params =~ s/\\{/{/g;
		$params =~ s/\\}/}/g;
		$params =~ s/\\\$/\$/g;

		# split parameters
		my @params = ();

		while (length($params) && $params =~ s/^([^\|\\]*(\\.[^\|\\]*)*)\|?//s) {
			my $p = $1;
			$p =~ s/\\\|/\|/g;

			push(@params, $p);
		}

		my $text = '';

		# is it a variable?
		if (defined $ah->{'vars'}->{$key}) {
			$text = $ah->{'vars'}->{$key};
			$text = $ah->params($text, @params);
		}

		# is it a function?
		elsif (defined $ah->{'funcs'}->{$key}) {
			my ($func);

			$func = $ah->{'funcs'}->{$key};
			$text = $func->(@params);

			# functions can abort further execution

			if (${$ah->{'abort-flag'}}) {
				last;
			}
		}

		# can it be loaded externally?
		elsif (defined $ah->{loader_func} &&
			(ref($ah->{loader_func}) eq 'CODE') &&
			defined($text = $ah->{loader_func}->($key))) {

			$text = $ah->params($text, @params);
		}

		# is it an include?
		elsif ($ah->{'include-path'}) {
			foreach my $p (@{$ah->{'include-path'}}) {
				if (open(INC, "$p/$key")) {
					$text = join('', <INC>);
					close INC;

					# cache it as a variable
					$ah->{vars}->{$key} = $text;

					$text = $ah->params($text, @params);

					last;
				}
			}
		}
		else {
			$text = $found;

			push(@{$ah->{'unresolved'}}, $found);

			if (ref $ah->{'AUTOLOAD'}) {
				$text = $ah->{'AUTOLOAD'}($found);
			}
		}

		$text ||= '';

		if ($ah->{debug}) {
			push(@{$ah->{call_stack}},
				[ $key, $level, $found, $text ]
			);
		}

		# do the recursivity
		$text = $ah->_process_do($text, $level + 1, $key) || '';

		# make the substitution
		$data =~ s/{-\Q$found\E}/$text/;
	}

	# if the template included cache info,
	# store the result there
	if ($cache_time) {
		open F, '>' . $ah->{'cache-path'} . '/' . $template_name;
		flock F, 2;
		print F $data;
		close F;
	}

	return $data;
}


sub init {
	my $self = shift;

	# special variables
	$self->{vars}->{'\n'}		= "\n";
	$self->{vars}->{'\BEGIN'}	||= '';
	$self->{vars}->{'\END'}		||= '';
	$self->{vars}->{'\VERSION'}	= $Artemus4::VERSION;

	# special functions
	$self->{funcs}->{localtime}	= sub { scalar(localtime) };

	$self->{funcs}->{if}		= sub { $_[0] ? $_[1] : (scalar(@_) == 3 ? $_[2] : '') };
	$self->{funcs}->{ifelse}	= $self->{funcs}->{if};

	$self->{funcs}->{ifeq}		= sub { $_[0] eq $_[1] ? $_[2] : (scalar(@_) == 4 ? $_[3] : '') };
	$self->{funcs}->{ifneq}		= sub { $_[0] ne $_[1] ? $_[2] : (scalar(@_) == 4 ? $_[3] : '') };
	$self->{funcs}->{ifeqelse}	= $self->{funcs}->{ifeq};

	$self->{funcs}->{add}		= sub { ($_[0] || 0) + ($_[1] || 0); };
	$self->{funcs}->{sub}		= sub { ($_[0] || 0) - ($_[1] || 0); };
	$self->{funcs}->{gt}		= sub { ($_[0] || 0) > ($_[1] || 0); };
	$self->{funcs}->{lt}		= sub { ($_[0] || 0) < ($_[1] || 0); };
	$self->{funcs}->{eq}		= sub { $_[0] eq $_[1] ? 1 : 0; };
	$self->{funcs}->{random}	= sub { $_[rand(scalar(@_))]; };

	$self->{funcs}->{and}		= sub { ($_[0] && $_[1]) || ''; };
	$self->{funcs}->{or}		= sub { $_[0] || $_[1] || ''; };
	$self->{funcs}->{not}		= sub { $_[0] ? 0 : 1; };

	$self->{funcs}->{foreach}	= sub {
		my $list	= shift;
		my $code	= shift || '$0';
		my $sep		= shift || '';
		my $hdr		= shift || '';

		my @ret = ();
		my @l = split(/\s*:\s*/, $list);
		my $ph = '';

		foreach my $l (@l) {
			my @e = split(/\s*,\s*/, $l);

			my $o = '';

			if ($hdr) {
				# generate header: parse parameters
				my $tc = $self->params($hdr, @e);

				# and process (we want the output of
				# the possible code, no the code itself)
				$tc = $self->_process_do($tc);

				# is it different from previous? add
				if ($tc ne $ph) {
					$o = $tc;
				}

				# store for later
				$ph = $tc;
			}

			# add main body
			$o .= $self->params($code, @e);

			push(@ret, $o);
		}

		return join($sep, @ret);
	};

	$self->{funcs}->{set} = sub { $self->{vars}->{$_[0]} = $_[1]; return ''; };

	$self->{funcs}->{case}	= sub {
		my $var		= shift;
		my $ret		= '';

		chomp($var);
		$var =~ s/\r//g;

		# if args are odd, the last one is
		# the 'otherwise' case
		if (scalar(@_) % 2) {
			$ret = pop(@_);
		}

		while (@_) {
			my $val = shift;
			my $out = shift;

			chomp($val);
			$val =~ s/\r//g;

			if ($var eq $val) {
				$ret = $out;
				last;
			}
		}

		return $ret;
	};

	$self->{funcs}->{env} = sub { scalar(@_) ? ($ENV{$_[0]} || '') : join(':', keys(%ENV)); };
	$self->{funcs}->{size} = sub { scalar(@_) ? split(/\s*:\s*/, $_[0]) : 0; };
	$self->{funcs}->{seq} = sub { join(':', ($_[0] || 0) .. ($_[1] || 0)); };
	$self->{funcs}->{item} = sub { (split(/\s*:\s*/, $_[0]))[$_[1]]; };

	$self->{funcs}->{sort} = sub {
		my $list	= shift;
		my $field	= shift || 0;

		join(':',
			sort {
				my @a = split(',', $a);
				my @b = split(',', $b);

				$a[$field] cmp $b[$field];
			} split(':', $list)
		);
	};

	$self->{funcs}->{reverse} = sub { join(':', reverse(split(':', $_[0]))); };

	$self->{_abort} = 0;
	$self->{_unresolved} = [];

	# ensure 'abort-flag' and 'unresolved' point to
	# appropriate holders
	$self->{'abort-flag'}	||= \$self->{_abort};
	$self->{unresolved}	||= \$self->{_unresolved};

	# fix include-path
	$self->{'include-path'}	||= [];

	if (!ref($self->{'include-path'})) {
		$self->{'include-path'} = [ split(/:/, $self->{'include-path'}) ];
	}

	return $self;
}


sub new {
	my ($class, %params) = @_;

	my $self = bless({ %params }, $class);

	return $self->init();
}


1;
__END__
=pod

=head1 NAME

Artemus4 - Template Toolkit

=head1 SYNOPSIS

 use Artemus4;
 
 # normal variables
 %vars = (
	"copyright" => 'Copyright 2002',   # normal variable
	"number" => 100,		   # another
	"about" => '{-copyright} My Self', # can be nested
	"link" => '<a href="$0">$1</a>'    # can accept parameters
	);
 
 # functions as templates
 %funcs = (
	"rnd" => sub { int(rand(100)) },    # normal function
	"sqrt" => sub { sqrt($_[0]) }	    # can accept parameters
	);
 
 # create a new Artemus4 instance
 $ah = new Artemus4( "vars" => \%vars, "funcs" => \%funcs );
 
 # do it
 $out = $ah->process('Click on {-link|http://my.page|my page}, {-about}');
 $out2 = $ah->process('The square root of {-number} is {-sqrt|{-number}}');

=head1 DESCRIPTION

Artemus4 is yet another template toolkit. Though it was designed
to preprocess HTML, it can be used for any task that involves
text substitution. These templates can be plain text, text with
parameters and hooks to real Perl code. This document describes
the Artemus4 markup as well as the API.

=for html <->

You can download the latest version of this package and get
more information from its home page at

 http://triptico.com/software/artemus.html

=head1 THE ARTEMUS MARKUP

=head2 Simple templates

The simplest Artemus4 template is just a text substitution. If
you set the 'about' template to '(C) 2000/2002 My Self', you
can just write in your text

 This software is {-about}.

and found it replaced by

 This software is (C) 2000/2002 My Self.

Artemus4 templates can be nestable; so, if you set another
template, called 'copyright' and containing '(C) 2000/2002', you
can set 'about' to be '{-copyright} My Self', and obtain the
same result. Though they can be nested nearly ad-infinitum, making
circular references is unwise.

=head2 Templates with parameters

This wouldn't be any cool if templates where just text substitutions.
But you can create templates that accept parameters just by including
$0, $1, $2... marks inside its content. This marks will be replaced
by the parameters used when inserting the call.

So, if you create the 'link' template containing

 <a href = "$0">$1</a>

you can insert the following call:

 {-link|http://triptico.com|Angel Ortega's Home Page}

As you can see, you use the | character as a separator
among the parameters and the template name itself.

=head2 Perl functions as templates

Anything more complicated than this would require the definition
of special functions provided by you. To do it, you just add
templates to the 'funcs' hash reference when the Artemus4 object
is created which values are references to Perl functions. For
example, you can create a function returning a random value
by using:

 $funcs{'rnd'} = sub { int(rand(100)) };

And each time the {-random} template is found, it is evaluated
and returns a random number between 0 and 99.

Functions also can accept parameters; so, if you define it as

 $funcs{'rnd'} = sub { int(rand($_[0])) };

then calling the template as

 {-rnd|500}

will return each time it's evaluated a random value between 0 and 499.

=head2 Aborting further execution from a function

If the I<abort-flag> argument is set to a scalar reference when creating
the Artemus4 object, template processing can be aborted by setting
this scalar to non-zero from inside a template function.

=head2 Caching templates

If a template is expensive or time consuming (probably because it
calls several template functions that take very much time), it can be
marked as cacheable. You must set the 'cache-path' argument for
this to work, and include the following special Artemus4 code
inside the template:

 {-\CACHE|number}

where I<number> is a number of days (or fraction of day) the
cache will remain cached before being re-evaluated. Individual
template functions cannot be cached; you must wrap them in a
normal template if need it.

=head2 Documenting templates

Artemus4 templates can contain documentation in Perl's POD format.
This POD documentation is stripped each time the template is evaluated
unless you create the Artemus4 object with the I<contains-pod> argument
set.

See http://www.perldoc.com/perl5.8.0/pod/perlpod.html and
http://www.perldoc.com/perl5.8.0/pod/perlpodspec.html for information
about writing POD documentation.

=head2 Unresolved templates

If a template is not found, it will be replaced by its name (that is,
stripped out of the {- and } and left there). Also, the names of the
unresolved templates are appended to an array referenced by the
I<unresolved> argument, if one was defined when the Artemus4 object
was created.

=head2 Predefined templates

=over 4

=head3 if

 {-if|condition|text}
 {-if|condition|text_if_true|text_unless_true}

If I<condition> is true, this template returns I<text>, or nothing
otherwise; in the 3 argument version, returns I<text_if_true> or
I<text_unless_true>. A condition is true if is not zero or the empty
string (the same as in Perl).

=head3 ifelse

This is an alias for the I<if> template provided for backwards-compatibility.
Don't use it.

=head3 ifeq

 {-ifeq|term1|term2|text}
 {-ifeq|term1|term2|text_if_true|text_unless_true}

If I<term1> is equal to I<term2>, this template returns I<text>, or nothing
otherwise. in the 4 argument version, returns I<text_if_true> or
I<text_unless_true>.

=head3 ifneq

 {-ifneq|term1|term2|text}

If I<term1> is not equal to I<term2>, this template returns I<text>, or
nothing otherwise.

=head3 ifeqelse

This is an alias for the I<ifeq> template provided for backwards-compatibility.
Don't use it.

=head3 add, sub

 {-add|num1|num2}
 {-sub|num1|num2}

This functions add or substract the values and returns the result.

=head3 gt, lt, eq

 {-gt|value1|value2}
 {-lt|value1|value2}
 {-eq|value1|value2}

This functions compare if I<value1> is greater-than, lesser-than or equal to
I<value2>. Meant primarily to use with the I<if> template.

=head3 random

 {-random|value1|value2|...}

This function returns randomly one of the values sent as arguments. There can
any number of arguments.

=head3 and

 {-and|value_or_condition_1|value_or_condition_2}

If both values are true or defined, returns I<value_or_condition_2>; otherwise,
returns the empty string.

=head3 or

 {-or|value_or_condition_1|value_or_condition_2}

If I<value_or_condition_1> is true or defined, returns it; otherwise, if
I<value_or_condition_2> is true or defined, returns it; otherwise, returns
the empty string.

=head3 not

 {-not|condition}

Returns the negation of I<condition>.

=head3 set

 {-set|template_name|value}

Assigns a value to a template. Same as setting a value from the 'vars'
argument to B<new>, but from Artemus4 code.

If you must change a variable from inside an I<if> directive, don't
forget to escape the I<set> directive, as in

 {-ifeq|{-user}|admin|\{-set\|powers\|EVERYTHING\}}

IF you don't escape it, the I<powers> variable will be inevitably set
to EVERYTHING.

=head3 foreach

 {-foreach|list:of:colon:separated:values|output_text|separator}

Iterates the list of colon separated values and returns I<output_text>
for each one of the values, separating each of them with I<separator>
(if one is defined). Each element itself can be a list of comma
separated values that will be split and assigned to the $0, $1... etc
parameters set to I<output_text>. For example, to create a I<select>
HTML tag:

 <select name = 'work_days'>
 {-foreach|Monday,1:Tuesday,2:Wednesday,3:Thursday,4:Friday,5|
 <option value = '\$1'>\$0</option>
 }
 </select>

Remember to escape the dollar signs to avoid being expanded too early,
and if the I<output_text> include calls to other Artemus4 templates,
to escape them as well.

=head3 case

 {-case|string|value_1|return_1|value_2|return_2|...}
 {-case|string|value_1|return_1|value_2|return_2|...|default_value}

Compares I<string> against the list of I<value_1>, I<value_2>... and
returns the appropriate I<return_1>, I<return_2>... value. If I<default_value>
is set (that is, I<case> has an odd number of arguments) it's returned
if I<string> does not match any value.

=head3 env

 {-env|environment_variable}
 {-env}

If I<environment_variable> has a value set in the environment, it's returned,
or the empty string otherwise. If no environment variable is set, returns
a colon-separated list of environment variable names.

=head3 size

 {-size|colon_separated_list}

Returns the number of elements in I<colon_separated_list>.

=head3 seq

 {-seq|from_number|to_number}

Generates a colon-separated list of the numbers from I<from_number>
to I<to_number>. Useful in a I<foreach> loop.

=head3 sort

 {-sort|list}
 {-sort|list|field}

Sorts the colon-separated list. The optional I<field> is the field
to sort on (assuming the elements of the list are comma-separated
lists themselves).

=head3 reverse

 {-reverse|list}

Reverses a colon-separated list.

=head3 \CACHE

 {-\CACHE|time}

Marks a template as cacheable and sets its cache time. See above.

=head3 \VERSION

 {-\VERSION}

Returns current Artemus4 version.

=head3 \BEGIN

=head3 \END

If you set these templates, they will be appended (\BEGIN) and
prepended (\END) to the text being processed.

=back

=head2 Escaping

Escaping has been briefly mentioned above; this is a way to avoid
prematurely expanding and executing Artemus4 templates, and a direct
derivative of the simple text substitution approach of the Artemus4
engine.

To escape an Artemus4 template call you must escape ALL characters
that has special meaning to the uber-simple Artemus4 parser (that is,
the opening and closing braces, the pipe argument separator and
the optional dollar prefixes for arguments). If you nest some
directives (for example, two I<foreach> calls), you must
double-escape everything. Yes, this can get really cumbersome.

=head1 FUNCTIONS AND METHODS

=cut

=head2 new

 $ah = new Artemus4(
	[ "vars" => \%variables, ]
	[ "funcs" => \%functions, ]
	[ "inv-vars" => \%inverse_variables, ]
	[ "include-path" => \@dir_with_templates_in_files, ]
	[ "loader_func" => \&template_loader_function, ]
	[ "cache-path" => $dir_to_store_cached_templates, ]
	[ "abort-flag" => \$abort_flag, ]
	[ "unresolved" => \@unresolved_templates, ]
	[ "use-cr-lf" => $boolean, ]
	[ "contains-pod" => $boolean, ]
	[ "paragraph-separator" => $separator, ]
	[ "strip-html-comments" => $boolean, ]
	[ "AUTOLOAD" => \&autoload_func ]
	);

Creates a new Artemus4 object. The following arguments (passed to it
as a hash) can be used:

=over 4

=head3 vars

This argument must be a reference to a hash containing
I<template> - I<content> pairs.

=head3 funcs

This argument must be a reference to a hash containing
I<template name> - I<code reference> pairs. Each time one of these
templates is evaluated, the function will be called with
the template parameters passed as the function's arguments.

=head3 inv-vars

This argument must be a reference to a hash containing
I<text> - I<content> pairs. Any occurrence of I<text> will be
replaced by I<content>. They are called 'inverse variables'
because they use to store variables that expand to Artemus4
markup, but can contain anything. This is really a plain
text substitution, so use it with care (B<NOTE>: this
option is disabled by now until it works correctly).

=head3 include-path

This arrayref should contain directories where templates are
to be found.

=head3 loader_func

If this reference to code exists, it's called with the template
name as argument as a method to load templates from external
sources. The function should return the template content or
C<undef> if the template is not found. It's called after testing
for variables or functions and before trying to load from
the C<include-path>.

=head3 cache-path

If this string is set, it must contain the path to a readable
and writable directory where the cacheable templates are cached.
See L<Caching templates> for further information.

=head3 abort-flag

This argument must be a reference to a scalar. When the template
processing is started, this scalar is set to 0. Template functions
can set it to any other non-zero value to stop template processing.

=head3 unresolved

If this argument points to an array reference, it will be filled
with the name of any unresolved templates. Each time a template
processing is started, the array is emptied.

=head3 use-cr-lf

If this flag is set, all lines are separated using CR/LF instead
of just LF (useful to generate MSDOS/Windows compatible text files).

=head3 contains-pod

If this flag is set, the (possible) POD documentation inside the
templates are not stripped-out. Understand this flag as saying
'this template has pod as part of its content, so do not strip it'.
See L<Documenting templates>.

=head3 paragraph-separator

If this argument is set to some string, all empty lines will be
substituted by it (can be another Artemus4 template).

=head3 strip-html-comments

If this flag is set, HTML comments are stripped before any
processing.

=head3 AUTOLOAD

If this argument points to a sub reference, the subrutine will
be executed when a template is unresolved and its return value used
as the final substitution value. Similar to the AUTOLOAD function
in Perl standard modules. The unresolved template name will be
sent as the first argument.

=back

=head2 armor

 $str = $ah->armor($str);

Translate Artemus4 markup to HTML entities, to avoid being
interpreted by the parser.

=head2 unarmor

 $str = $ah->unarmor($str);

Translate back the Artemus4 markup from HTML entities. This
is the reverse operation of B<armor>.

=head2 strip

 $str = $ah->strip($str);

Strips all Artemus4 markup from the string.

=head2 params

 $str = $ah->params($str, @params);

Interpolates all $0, $1, $2... occurrences in the string into
the equivalent element from @params.

=head2 process

 $str = $ah->process($str);

Processes the string, translating all Artemus4 markup. This
is the main template processing method. The I<abort-flag> flag and
I<unresolved> list are reset on each call to this method.

=head1 AUTHOR

Angel Ortega angel@triptico.com


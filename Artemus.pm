#####################################################################
#
#   Artemus - Template Toolkit
#
#   Copyright (C) 2000/2007 Angel Ortega <angel@triptico.com>
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
#   http://www.triptico.com
#
#####################################################################

use locale;

package Artemus;

use strict;
use warnings;

$Artemus::VERSION = '4.1.0-dev';

=pod

=head1 NAME

Artemus - Template Toolkit

=head1 SYNOPSIS

 use Artemus;
 
 # normal variables
 %vars = (
	"copyright" => 'Copyright 2002',   # normal variable
	"number" => 100,		   # another
	"about" => '{-copyright} My Self', # can be nested
	"link" => '<a href="$0">$1</a>'    # can accept parameters
	);
 
 # functions as templates
 %funcs = (
	"random" => sub { int(rand(100)) }, # normal function
	"sqrt" => sub { sqrt($_[0]) }	    # can accept parameters
	);
 
 # create a new Artemus instance
 $ah = new Artemus( "vars" => \%vars, "funcs" => \%funcs );
 
 # do it
 $out = $ah->process('Click on {-link|http://my.page|my page}, {-about}');
 $out2 = $ah->process('The square root of {-number} is {-sqrt|{-number}}');

=head1 DESCRIPTION

Artemus is yet another template toolkit. Though it was designed
to preprocess HTML, it can be used for any task that involves
text substitution. These templates can be plain text, text with
parameters and hooks to real Perl code. This document describes
the Artemus markup as well as the API.

You can download the latest version of this package and get
more information from its home page at

 http://www.triptico.com/software/artemus.html

=head1 THE ARTEMUS MARKUP

=head2 Simple templates

The simplest Artemus template is just a text substitution. If
you set the 'about' template to '(C) 2000/2002 My Self', you
can just write in your text

 This software is {-about}.

and found it replaced by

 This software is (C) 2000/2002 My Self.

Artemus templates can be nestable; so, if you set another
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

 {-link|http://www.triptico.com|Angel Ortega's Home Page}

As you can see, you use the | character as a separator
among the parameters and the template name itself.

=head2 Perl functions as templates

Anything more complicated than this would require the definition
of special functions provided by you. To do it, you just add
templates to the 'funcs' hash reference when the Artemus object
is created which values are references to Perl functions. For
example, you can create a function returning a random value
by using:

 $funcs{'random'} = sub { int(rand(100)) };

And each time the {-random} template is found, it is evaluated
and returns a random number between 0 and 99.

Functions also can accept parameters; so, if you define it as

 $funcs{'random'} = sub { int(rand($_[0])) };

then calling the template as

 {-random|500}

will return each time it's evaluated a random value between 0 and 499.

=head2 Aborting further execution from a function

If the I<abort-flag> argument is set to a scalar reference when creating
the Artemus object, template processing can be aborted by setting
this scalar to non-zero from inside a template function.

=head2 Caching templates

If a template is expensive or time consuming (probably because it
calls several template functions that take very much time), it can be
marked as cacheable. You must set the 'cache-path' argument for
this to work, and include the following special Artemus code
inside the template:

 {-\CACHE|number}

where I<number> is a number of days (or fraction of day) the
cache will remain cached before being re-evaluated. Individual
template functions cannot be cached; you must wrap them in a
normal template if need it.

=head2 Documenting templates

Artemus templates can contain documentation in Perl's POD format.
This POD documentation is stripped each time the template is evaluated
unless you create the Artemus object with the I<contains-pod> argument
set.

See http://www.perldoc.com/perl5.8.0/pod/perlpod.html and
http://www.perldoc.com/perl5.8.0/pod/perlpodspec.html for information
about writing POD documentation.

=head2 Unresolved templates

If a template is not found, it will be replaced by its name (that is,
stripped out of the {- and } and left there). Also, the names of the
unresolved templates are appended to an array referenced by the
I<unresolved> argument, if one was defined when the Artemus object
was created.

=head2 Predefined templates

=over 4

=item B<if>

 {-if|condition|text}

If I<condition> is true, this template returns I<text>, or nothing
otherwise. A condition is true if is not zero or the empty string
(the same as in Perl).

=item B<ifelse>

 {-ifelse|condition|text_if_true|text_unless_true}

If I<condition> is true, this template returns I<text_if_true>, or
I<text_unless_true> otherwise.

=item B<ifeq>

 {-ifeq|term1|term2|text}

If I<term1> is equal to I<term2>, this template returns I<text>, or nothing
otherwise.

=item B<ifneq>

 {-ifneq|term1|term2|text}

If I<term1> is not equal to I<term2>, this template returns I<text>, or
nothing otherwise.

=item B<ifeqelse>

 {-ifeqelse|term1|term2|text_if_true|text_unless_true}

If I<term1> is equal to I<term2>, this template returns I<text_if_true>, or
I<text_unless_true> otherwise.

=item B<\CACHE>

 {-\CACHE|time}

Marks a template as cacheable and sets its cache time. See above.

=item B<\VERSION>

 {-\VERSION}

Returns current Artemus version.

=item B<\BEGIN>

=item B<\END>

If you set these templates, they will be appended (\BEGIN) and
prepended (\END) to the text being processed.

=back

=head1 FUNCTIONS AND METHODS

=cut

=head2 B<new>

 $ah = new Artemus(
	[ "vars" => \%variables, ]
	[ "funcs" => \%functions, ]
	[ "inv-vars" => \%inverse_variables, ]
	[ "include-path" => $dir_with_templates_in_files, ]
	[ "cache-path" => $dir_to_store_cached_templates, ]
	[ "abort-flag" => \$abort_flag, ]
	[ "unresolved" => \@unresolved_templates, ]
	[ "use-cr-lf" => $boolean, ]
	[ "contains-pod" => $boolean, ]
	[ "paragraph-separator" => $separator, ]
	[ "strip-html-comments" => $boolean, ]
	[ "AUTOLOAD" => \&autoload_func ]
	);

Creates a new Artemus object. The following arguments (passed to it
as a hash) can be used:

=over 4

=item I<vars>

This argument must be a reference to a hash containing
I<template> - I<content> pairs.

=item I<funcs>

This argument must be a reference to a hash containing
I<template name> - I<code reference> pairs. Each time one of these
templates is evaluated, the function will be called with
the template parameters passed as the function's arguments.

=item I<inv-vars>

This argument must be a reference to a hash containing
I<text> - I<content> pairs. Any occurrence of I<text> will be
replaced by I<content>. They are called 'inverse variables'
because they use to store variables that expand to Artemus
markup, but can contain anything. This is really a plain
text substitution, so use it with care (B<NOTE>: this
option is disabled by now until it works correctly).

=item I<include-path>

If this string is set, it must point to a readable directory
that contains templates, one on each file. The file names
will be treated as template names. Many directories can
be specified by separating them with colons.

=item I<cache-path>

If this string is set, it must contain the path to a readable
and writable directory where the cacheable templates are cached.
See L<Caching templates> for further information.

=item I<abort-flag>

This argument must be a reference to a scalar. When the template
processing is started, this scalar is set to 0. Template functions
can set it to any other non-zero value to stop template processing.

=item I<unresolved>

If this argument points to an array reference, it will be filled
with the name of any unresolved templates. Each time a template
processing is started, the array is emptied.

=item I<use-cr-lf>

If this flag is set, all lines are separated using CR/LF instead
of just LF (useful to generate MSDOS/Windows compatible text files).

=item I<contains-pod>

If this flag is set, the (possible) POD documentation inside the
templates are not stripped-out. Understand this flag as saying
'this template has pod as part of its content, so do not strip it'.
See L<Documenting templates>.

=item I<paragraph-separator>

If this argument is set to some string, all empty lines will be
substituted by it (can be another Artemus template).

=item I<strip-html-comments>

If this flag is set, HTML comments are stripped before any
processing.

=item I<AUTOLOAD>

If this argument points to a sub reference, the subrutine will
be executed when a template is unresolved and its return value used
as the final substitution value. Similar to the AUTOLOAD function
in Perl standard modules. The unresolved template name will be
sent as the first argument.

=back

=cut

sub new
{
	my ($class, %params) = @_;

	my $a = bless({ %params }, $class);

	# special variables
	$a->{'vars'}->{'\n'}		= "\n";
	$a->{'vars'}->{'\BEGIN'}	||= '';
	$a->{'vars'}->{'\END'}		||= '';
	$a->{'vars'}->{'\VERSION'}	= $Artemus::VERSION;

	# special functions
	$a->{'funcs'}->{'localtime'}	= sub { scalar(localtime) };
	$a->{'funcs'}->{'if'}		= sub { $_[0] ? return $_[1] : return '' };
	$a->{'funcs'}->{'ifelse'}	= sub { $_[0] ? return $_[1] : return $_[2] };
	$a->{'funcs'}->{'ifeq'}		= sub { $_[0] eq $_[1] ? return $_[2] : return '' };
	$a->{'funcs'}->{'ifneq'}	= sub { $_[0] ne $_[1] ? return $_[2] : return '' };
	$a->{'funcs'}->{'ifeqelse'}	= sub { $_[0] eq $_[1] ? return $_[2] : return $_[3] };

	$a->{funcs}->{'foreach'}	= sub {
		my $list	= shift;
		my $code	= shift;
		my $sep		= shift || '';

		my @ret = ();

		foreach my $l (split(/:/, $list)) {
			my @e = split(/,/, $l);

			push(@ret, $a->params($code, @e));
		}

		return join($sep, @ret);
	};

	return $a;
}


=head2 B<armor>

 $str = $ah->armor($str);

Translate Artemus markup to HTML entities, to avoid being
interpreted by the parser.

=cut

sub armor
{
	my ($ah, $t) = @_;

	$t =~ s/{/\&#123;/g;
	$t =~ s/\|/\&#124;/g;
	$t =~ s/}/\&#125;/g;
	$t =~ s/\$/\&#36;/g;
	$t =~ s/=/\&#61;/g;

	return $t;
}


=head2 B<unarmor>

 $str = $ah->unarmor($str);

Translate back the Artemus markup from HTML entities. This
is the reverse operation of B<armor>.

=cut

sub unarmor
{
	my ($ah, $t) = @_;

	$t =~ s/\&#123;/{/g;
	$t =~ s/\&#124;/\|/g;
	$t =~ s/\&#125;/}/g;
	$t =~ s/\&#36;/\$/g;
	$t =~ s/\&#61;/=/g;

	return $t;
}


=head2 B<strip>

 $str = $ah->strip($str);

Strips all Artemus markup from the string.

=cut

sub strip
{
	my ($ah, $t) = @_;

	$t =~ s/{-([-\\\w_ \.]+)[^{}]*}/$1/g;

	return $t;
}


=head2 B<params>

 $str = $ah->params($str,@params);

Interpolates all $0, $1, $2... occurrences in the string into
the equivalent element from @params.

=cut

sub params
{
	my ($ah, $t, @params) = @_;

	for(my $n = 0; $n < scalar(@params); $n++) {
		$t =~ s/(^|[^\\])\$$n/$1$params[$n]/g;
	}

	return $t;
}


=head2 B<process>

 $str = $ah->process($str);

Processes the string, translating all Artemus markup. This
is the main template processing method. The I<abort-flag> flag and
I<unresolved> list are reset on each call to this method.

=cut

sub process
{
	my ($ah, $data) = @_;

	# not aborted by now
	if (ref ($ah->{'abort-flag'})) {
		${$ah->{'abort-flag'}} = 0;
	}

	# no unresolved templates by now
	if (ref ($ah->{'unresolved'})) {
		@{$ah->{'unresolved'}} = ();
	}

	# surround with \BEGIN and \END
	$data = $ah->{'vars'}->{'\BEGIN'} . $data . $ah->{'vars'}->{'\END'};

	# really do it, recursively
	$data = $ah->_process_do($data);

	# finally, convert end of lines if necessary
	if ($ah->{'use-cr-lf'}) {
		$data =~ s/\n/\r\n/g;
	}

	# strip comments
	$data =~ s/{%[^}]+}//g;

	return $data;
}


sub _process_do
{
	my ($ah, $data, $template_name) = @_;
	my ($cache_time);

	if ($ah->{debug}) {
		print STDERR sprintf('Artemus: template="%s", data="%s"',
			$template_name || 'NONE', $data || ''), "\n";
	}

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

		while ($params && $params =~ s/^([^\|\\]*(\\.[^\|\\]*)*)\|?//s) {
			push(@params, $1);
		}

		my $text = undef;

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

			if (ref($ah->{'abort-flag'}) and $$ah->{'abort-flag'}) {
				last;
			}
		}

		# is it an include?
		elsif ($ah->{'include-path'}) {
			foreach my $p (split(/:/, $ah->{'include-path'})) {
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

		unless (defined $text) {
			$text = $found;

			if (ref $ah->{'unresolved'}) {
				push(@{$ah->{'unresolved'}}, $found);
			}

			if (ref $ah->{'AUTOLOAD'}) {
				$text = $ah->{'AUTOLOAD'}($found);
			}
		}

		# do the recursivity
		# if params are not to be cached,
		# use $key instead of $found
		$text = $ah->_process_do($text, $found);

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


=head1 AUTHOR

Angel Ortega angel@triptico.com

=cut

1;

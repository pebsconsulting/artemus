###########################################
#
# Artemus main processing function
#
###########################################
# -*- Mode: Perl

use locale;

sub artemus
{
	my ($data,%opts)=@_;
	my ($vars,$inv_vars,$funcs);

	# abort flag not set
	$artemus_abort=0;

	$vars=$opts{'vars'};
	$funcs=$opts{'funcs'};

	# special values:
	# {-\n}, substitutes as \n
	$vars->{"\\n"}||="\n";

	# special functions
	$funcs->{"localtime"}||=sub { scalar(localtime) };
	$funcs->{"if"}||=sub { $_[0] ? return($_[1]) : return("") };
	$funcs->{"ifelse"}||=sub { $_[0] ? return($_[1]) : return($_[2]) };

	$data=artemus_do(undef,$data, %opts);
}


sub artemus_do
{
	my ($template,$data,%opts)=@_;
	my ($vars,$inv_vars,$funcs);
	my ($unresolved,$cache);

	# test if the template includes cache info
	if($data =~ s/{-\\CACHE\|([^}]*)}//)
	{
		if($template and $opts{'cache_path'})
		{
			$cache=$1;
			my ($c)=$opts{'cache_path'};

			if(-r "$c/$template" and
			   -M "$c/$template" < $cache)
			{
				open F, "$c/$template";
				flock F, 1;
				$data=join("",<F>);
				close F;

				return($data);
			}
		}
	}

	# strip POD documentation
	if($data =~ /=cut/ and not $opts{'contains_pod'})
	{
		my (@d);

		foreach (split("\n",$data))
		{
			push(@d, $_) unless(/^=/ .. /^=cut/);
		}

		$data=join("\n",@d);
	}

	# make hashes comfortable
	$vars=$opts{'vars'};
	$inv_vars=$opts{'inv-vars'};
	$funcs=$opts{'funcs'};
	$unresolved=$opts{'unresolved'};

	# if defined, substitute the paragraphs
	# with the paragraph separator
	if($opts{'paragraph-separator'})
	{
		$data =~ s/\n\n/\n$opts{'paragraph-separator'}\n/g;
	}

	# concat special variables BEGIN & END
	$data = $vars->{"\\BEGIN"} . $data . $vars->{"\\END"};

	# inverse substitutions
	for my $i (keys(%$inv_vars))
	{
		next if $inv_vars->{$i} =~ /\$/;
		next if $i =~ /^\-/;
		$data =~ s/\b($i)\b/\{\-$1\}/g;
	}

	# main function, variable and include substitutions
	while($data =~ /{-([^}{]*)}/s)
	{
		my ($found)=$1;
		my ($key,@params,$text,$n);

		($key,@params)=split(/\|/,$found);

		# exclude dangerous keys
		unless($key =~ /^[-\\\w_ \.]+$/)
		{
			$text=$key;
		}

		# is it a variable?
		elsif(defined $vars->{$key})
		{
			$text=$vars->{$key};

			for($n=0;$text =~ /\$$n/;$n++)
			{
				$text =~ s/\$$n/$params[$n]/g;
			}
		}

		# is it a function?
		elsif(defined $funcs->{$key})
		{
			my ($func);

			$func=$funcs->{$key};
			$text=&$func(@params);

			# functions can abort further execution
			last if $artemus_abort;
		}
		# is it an include?
		elsif($opts{'include-path'})
		{
			foreach my $p (split(/:/,$opts{'include-path'}))
			{
				if(open(INC, "$p/$key"))
				{
					$text=join("",<INC>);
					close INC;

					for($n=0;$text =~ /\$$n/;$n++)
					{
						$text =~ s/\$$n/$params[$n]/g;
					}

					last;
				}
			}
		}

		unless(defined $text)
		{
#			 print STDERR "unresolved: '$found'\n" if not $quiet;
			push(@$unresolved,$found);
			$text=$found;
		}

		# do the recursivity
		$text=artemus_do($key,$text,%opts);

		# make the substitution
		$data =~ s/{-\Q$found\E}/$text/;
	}

	# finally, convert end of lines if necessary
	$data =~ s/\n/\r\n/g if($opts{'use-cr-lf'});

	# if the template included cache info,
	# store the result there
	if($cache)
	{
		open F, ">".$opts{'cache_path'}."/".$template;
		flock F,2;
		print F $data;
		close F;
	}

	return($data);
}


1;

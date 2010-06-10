use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Artemus',
    'dist'		=> { COMPRESS => gzip, SUFFIX => '.gz'},
    'VERSION_FROM'	=> 'Art5.pm',
    'EXE_FILES' 	=> [ 'artemus', 'art5' ],
    'INSTALLSCRIPT'	=> '/usr/local/bin',
);

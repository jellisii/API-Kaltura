

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'API::Kaltura',
    VERSION_FROM => 'lib/API/Kaltura.pm', # finds \$VERSION
    AUTHOR       => 'J. Eric Ellis (jellisii@gmail.com)',
    ABSTRACT     => 'Kaltura API implementation.',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                     'XML::Twig' => 0,
                     'LWP' => 0,
                     'Carp' => 0
                    },
);

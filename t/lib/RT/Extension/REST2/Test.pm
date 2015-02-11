package RT::Extension::REST2::Test;

use strict;
use warnings;
use base 'RT::Test';

use RT::Extension::REST2;
use Test::WWW::Mechanize::PSGI;

sub mech {
    my $mech = Test::WWW::Mechanize::PSGI->new(
        app => RT::Extension::REST2->to_app,
    );
}

sub authorization_header { return 'Basic cm9vdDpwYXNzd29yZA==' }

1;

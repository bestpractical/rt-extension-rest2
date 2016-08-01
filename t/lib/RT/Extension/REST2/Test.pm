package RT::Extension::REST2::Test;

use strict;
use warnings;
use base 'RT::Test';

use RT::Extension::REST2;
use Test::WWW::Mechanize::PSGI;
use RT::User;

sub mech {
    my $mech = Test::WWW::Mechanize::PSGI->new(
        app => RT::Extension::REST2->to_app,
    );
}

{
    my $u;

    sub authorization_header {
        $u = _create_user() unless ($u && $u->id);
        return 'Basic dGVzdDpwYXNzd29yZA==';
    }

    sub user {
        $u = _create_user() unless ($u && $u->id);
        return $u;
    }

    sub _create_user {
        my $u = RT::User->new( RT->SystemUser );
        $u->Create(
            Name => 'test',
            Password => 'password',
            Privileged => 1,
        );
        $u->PrincipalObj->GrantRight( Right => 'SuperUser' );
        return $u;
    }
}

1;

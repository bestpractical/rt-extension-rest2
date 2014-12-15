package RT::Extension::REST2::Middleware::Auth;

use strict;
use warnings;

use base 'Plack::Middleware::Auth::Basic';

use Class::Method::Modifiers;

before prepare_app => sub {
    my $self = shift;
    $self->realm( RT->Config->Get('rtname') . ' REST API' );

    $self->authenticator(sub {
        my ($user, $pass, $env) = @_;
        my $cu = RT::CurrentUser->new;
        $cu->Load($user);
        if ($cu->id and $cu->IsPassword($pass)) {
            $env->{'rt.current_user'} = $cu;
            return 1;
        }
        else {
            RT->Logger->info("Failed login for $user");
            return 0;
        }
    });
};

1;

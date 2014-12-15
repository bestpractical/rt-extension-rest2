package RT::Extension::REST2::Resource;
use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;

extends 'Web::Machine::Resource';

has 'current_user' => (
    is          => 'ro',
    isa         => 'RT::CurrentUser',
    required    => 1,
    lazy_build  => 1,
);

# XXX TODO: real sessions
sub _build_current_user {
    $_[0]->request->env->{"rt.current_user"} || RT::CurrentUser->new;
}

__PACKAGE__->meta->make_immutable;

1;

package RTx::REST::Resource::Tickets;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RTx::REST::Resource::Collection';

sub limit_collection {
    my ($self, $tickets) = @_;
    my ($ok, $msg) = $tickets->FromSQL(
        $self->request->param('query') || ""
    );
    # XXX TODO: thread errors back to client; abort request with 4xx code?
}

__PACKAGE__->meta->make_immutable;

1;

package RTx::REST::Resource::Tickets;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RTx::REST::Resource::Collection';

use RT::Search::Simple;

sub limit_collection {
    my ($self, $tickets) = @_;
    my $query = $self->request->param('query') || "";

    if ($self->request->param('simple') and $query) {
        # XXX TODO: Note that "normal" ModifyQuery callback isn't invoked
        # XXX TODO: Special-casing of "#NNN" isn't used
        my $search = RT::Search::Simple->new(
            Argument    => $query,
            TicketsObj  => $tickets,
        );
        $query = $search->QueryToSQL;
    }

    my ($ok, $msg) = $tickets->FromSQL($query);
    # XXX TODO: thread errors back to client; abort request with 4xx code?
}

__PACKAGE__->meta->make_immutable;

1;

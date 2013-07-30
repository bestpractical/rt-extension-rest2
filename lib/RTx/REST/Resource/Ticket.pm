package RTx::REST::Resource::Ticket;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RTx::REST::Resource';
with 'RTx::REST::Resource::Role::Record';

sub forbidden {
    my $self = shift;
    return 0 if not $self->record->id;
    return 0 if $self->record->CurrentUserHasRight("ShowTicket");
    return 1;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

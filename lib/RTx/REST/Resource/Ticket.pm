package RTx::REST::Resource::Ticket;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RTx::REST::Resource::Record';
with 'RTx::REST::Resource::Record::Readable';
with 'RTx::REST::Resource::Record::Deletable';
with 'RTx::REST::Resource::Record::Writable';

sub forbidden {
    my $self = shift;
    return 0 if not $self->record->id;
    return 0 if $self->record->CurrentUserHasRight("ShowTicket");
    return 1;
}

sub create_record {
    my $self = shift;
    my $data = shift;
    my ($ok, $txn, $msg) = $self->record->Create(%$data);
    return ($ok, $msg);
}

__PACKAGE__->meta->make_immutable;

1;

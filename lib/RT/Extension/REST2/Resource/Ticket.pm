package RT::Extension::REST2::Resource::Ticket;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Record';
with 'RT::Extension::REST2::Resource::Record::Readable';
with 'RT::Extension::REST2::Resource::Record::Deletable';
with 'RT::Extension::REST2::Resource::Record::Writable';

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

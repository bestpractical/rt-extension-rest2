package RT::Extension::REST2::Resource::Ticket;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Record';
with (
    'RT::Extension::REST2::Resource::Record::Readable',
    'RT::Extension::REST2::Resource::Record::Hypermedia'
        => { -alias => { hypermedia_links => '_default_hypermedia_links' } },
    'RT::Extension::REST2::Resource::Record::Deletable',
    'RT::Extension::REST2::Resource::Record::Writable',
);

sub create_record {
    my $self = shift;
    my $data = shift;
    my ($ok, $txn, $msg) = $self->record->Create(%$data);
    return ($ok, $msg);
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->record->id;
    return !$self->record->CurrentUserHasRight('ShowTicket');
}

sub hypermedia_links {
    my $self = shift;
    my $links = $self->_default_hypermedia_links(@_);
    push @$links, $self->_transaction_history_link;
    return $links;
}

__PACKAGE__->meta->make_immutable;

1;

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

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/ticket/?$},
        block => sub { { record_class => 'RT::Ticket' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/ticket/(\d+)$},
        block => sub { { record_class => 'RT::Ticket', record_id => shift->pos(1) } },
    )
}

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
    my $self_link = $self->_self_link;
    my $links = $self->_default_hypermedia_links(@_);

    push @$links, $self->_transaction_history_link;

    push @$links, {
            ref     => 'correspond',
            _url    => $self_link->{_url} . '/correspond',
    } if $self->record->CurrentUserHasRight('ReplyToTicket');

    push @$links, {
        ref     => 'comment',
        _url    => $self_link->{_url} . '/comment',
    } if $self->record->CurrentUserHasRight('CommentOnTicket');

    return $links;
}

__PACKAGE__->meta->make_immutable;

1;

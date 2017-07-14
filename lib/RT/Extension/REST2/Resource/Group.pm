package RT::Extension::REST2::Resource::Group;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use RT::Extension::REST2::Util qw(expand_uid);

extends 'RT::Extension::REST2::Resource::Record';
with 'RT::Extension::REST2::Resource::Record::Readable'
        => { -alias => { serialize => '_default_serialize' } },
    'RT::Extension::REST2::Resource::Record::Hypermedia'
        => { -alias => { hypermedia_links => '_default_hypermedia_links' } };

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/group/?$},
        block => sub { { record_class => 'RT::Group' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/group/(\d+)/?$},
        block => sub { { record_class => 'RT::Group', record_id => shift->pos(1) } },
    )
}

sub serialize {
    my $self = shift;
    my $data = $self->_default_serialize(@_);

    $data->{Members} = [
        map { expand_uid($_->MemberObj->Object->UID) }
        @{ $self->record->MembersObj->ItemsArrayRef }
    ];

    return $data;
}

sub hypermedia_links {
    my $self = shift;
    my $links = $self->_default_hypermedia_links(@_);
    push @$links, $self->_transaction_history_link;
    return $links;
}

__PACKAGE__->meta->make_immutable;

1;


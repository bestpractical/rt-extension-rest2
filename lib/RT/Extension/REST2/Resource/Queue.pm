package RT::Extension::REST2::Resource::Queue;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Record';
with (
    'RT::Extension::REST2::Resource::Record::Readable',
    'RT::Extension::REST2::Resource::Record::Hypermedia'
        => { -alias => { hypermedia_links => '_default_hypermedia_links' } },
    'RT::Extension::REST2::Resource::Record::DeletableByDisabling',
    'RT::Extension::REST2::Resource::Record::Writable',
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/queue/?$},
        block => sub { { record_class => 'RT::Queue' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/queue/(\d+)/?$},
        block => sub { { record_class => 'RT::Queue', record_id => shift->pos(1) } },
    )
}

sub hypermedia_links {
    my $self = shift;
    my $links = $self->_default_hypermedia_links(@_);
    my $queue = $self->record;

    push @$links, $self->_transaction_history_link;

    return $links;
}

__PACKAGE__->meta->make_immutable;

1;

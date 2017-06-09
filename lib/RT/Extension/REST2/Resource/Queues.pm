package RT::Extension::REST2::Resource::Queues;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/queues/?$},
        block => sub { { collection_class => 'RT::Queues' } },
    ),
}

__PACKAGE__->meta->make_immutable;

1;

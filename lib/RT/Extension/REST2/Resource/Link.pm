package RT::Extension::REST2::Resource::Link;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Record';
with 'RT::Extension::REST2::Resource::Record::Readable',
     'RT::Extension::REST2::Resource::Record::Hypermedia';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^(Add|Delete)Link$},
        block => sub { { record_class => 'RT::Link' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^(Add|Delete)Link$},
        block => sub { { record_class => 'RT::Link', record_id => shift->pos(1) } },
    )
}

__PACKAGE__->meta->make_immutable;

1;


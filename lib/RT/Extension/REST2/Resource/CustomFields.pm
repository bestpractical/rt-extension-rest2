package RT::Extension::REST2::Resource::CustomFields;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/customfields/?$},
        block => sub { { collection_class => 'RT::CustomFields' } },
    ),
}

__PACKAGE__->meta->make_immutable;

1;


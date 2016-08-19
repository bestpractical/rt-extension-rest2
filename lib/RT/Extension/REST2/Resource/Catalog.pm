package RT::Extension::REST2::Resource::Catalog;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Record';
with 'RT::Extension::REST2::Resource::Record::Readable';
with 'RT::Extension::REST2::Resource::Record::DeletableByDisabling';
with 'RT::Extension::REST2::Resource::Record::Writable';

__PACKAGE__->meta->make_immutable;

1;

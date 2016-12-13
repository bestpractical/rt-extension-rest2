package RT::Extension::REST2::Resource::Transaction;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Record';
with 'RT::Extension::REST2::Resource::Record::Readable';

__PACKAGE__->meta->make_immutable;

1;


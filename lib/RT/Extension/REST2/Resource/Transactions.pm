package RT::Extension::REST2::Resource::Transactions;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::QueryByJSON';

__PACKAGE__->meta->make_immutable;

1;

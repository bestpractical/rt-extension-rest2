package RTx::REST::Resource::Queues;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RTx::REST::Resource::Collection';
with 'RTx::REST::Resource::Collection::QueryByJSON';

__PACKAGE__->meta->make_immutable;

1;

package RTx::REST::Resource::Queue;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RTx::REST::Resource::Record';
with 'RTx::REST::Resource::Record::Readable';
with 'RTx::REST::Resource::Record::DeletableByDisabling';
with 'RTx::REST::Resource::Record::Writable';

__PACKAGE__->meta->make_immutable;

1;

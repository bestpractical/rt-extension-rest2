package RTx::REST::Resource::Queue;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RTx::REST::Resource::Record';

__PACKAGE__->meta->make_immutable;

1;

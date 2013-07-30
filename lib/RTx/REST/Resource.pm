package RTx::REST::Resource;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'Web::Machine::Resource';

sub finish_request {
    my ($self, $meta) = @_;
    if ($meta->{exception}) {
        RT->Logger->crit("Error processing resource request: $meta->{exception}");
    }
}

1;

package RTx::REST::Resource;
use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;

extends 'Web::Machine::Resource';

sub finish_request {
    my ($self, $meta) = @_;
    if ($meta->{exception}) {
        RT->Logger->crit("Error processing resource request: $meta->{exception}");
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

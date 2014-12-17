package RT::Extension::REST2::Dispatcher;

use strict;
use warnings;
use Web::Simple;
use Web::Machine;

sub dispatch_request {
    my ($self) = @_;
    sub (/*/*) {
        my $resource_name = ucfirst lc $_[1];
        my $resource = "RT::Extension::REST2::Resource::${resource_name}";
        if ( $resource->require ) {
            Web::Machine->new(
                resource => $resource,
            )->to_app;
        }
        else {
            return undef;
        }
    },
}

1;

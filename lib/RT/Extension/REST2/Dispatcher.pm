package RT::Extension::REST2::Dispatcher;

use strict;
use warnings;
use Web::Simple;
use Web::Machine;
use Web::Dispatch::HTTPMethods;

sub dispatch_request {
    my ($self, $env) = @_;
    sub (/**) {
        my ($resource_name) = ucfirst(lc $_[1]) =~ /([^\/]+)\/?/;
        my $resource = "RT::Extension::REST2::Resource::${resource_name}";
        if ( $resource->require ) {
            return Web::Machine->new(
                resource => $resource,
            )->to_app;
        }
        else {
            return undef;
        }
    },
    sub () {
        my $resource = "RT::Extension::REST2::Resource::Root";
        $resource->require;
        my $root = Web::Machine->new(
            resource => $resource,
        )->to_app;

        sub (~) { GET { $root->($env) } },
        sub (/) { GET { $root->($env) } },
    }
}

1;

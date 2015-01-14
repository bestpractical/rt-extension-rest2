package RT::Extension::REST2::Dispatcher;

use strict;
use warnings;
use Web::Simple;
use Web::Machine;
use RT::Extension::REST2::PodViewer 'podview_as_html';

sub dispatch_request {
    my ($self) = @_;
    sub (/) {
        return [
            200,
            ['Content-Type' => 'text/html; charset=utf-8'],
            [ podview_as_html('RT::Extension::REST2') ]
        ];
    },
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

package RT::Extension::REST2::Resource::Root;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use RT::Extension::REST2::PodViewer 'podview_as_html';

extends 'RT::Extension::REST2::Resource';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/?$},
    );
}

sub content_types_provided { [{ 'text/html' => 'to_html' }] }
sub charsets_provided      { [ 'utf-8' ] }
sub default_charset        {   'utf-8'   }
sub allowed_methods        { ['GET', 'HEAD', 'OPTIONS'] }

sub to_html {
    return podview_as_html('RT::Extension::REST2') 
}

__PACKAGE__->meta->make_immutable;

1;


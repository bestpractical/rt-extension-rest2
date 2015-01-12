package RT::Extension::REST2::PodViewer;

use strict;
use warnings;
use Module::Path 'module_path';
use Pod::POM;
use Pod::POM::View::HTML;

use Sub::Exporter -setup => {
    exports => [qw(podview_as_html)]
};

sub podview_as_html {
    my ($module_name) = @_;
    my $pom = Pod::POM->new->parse( module_path($module_name) );
    return $pom->present('Pod::POM::View::HTML');
}

1;

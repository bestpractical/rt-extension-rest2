package RT::Extension::REST2::PodViewer::HTMLView;

use strict;
use warnings;
use base 'Pod::POM::View::HTML';

sub view_pod {
    my ($self, $pod) = @_;
    my $title = q{<title>RT::Extension::REST2</title>};
    my $style = <<'END_STYLE';
<style type="text/css">
body {
    bgcolor: #ffffff;
    margin: 0;
    border: 0 solid #000;
    padding: 0;
    padding-top: 0.1px
}
h1, h2, h3, h4, h5, h6, p {
    margin: 15px 10px;
}
h1 { font-size: 1.5em }
h2 { font-size:1.3em }
h3 { font-size:1.1em }
h4 { font-size:1.0em }
h1, h2, h3 { font-weight: bold }
pre {
    color: #333333;
    background-color: #f5f5f5;
    border: 1px solid #cccccc;
    padding: 8.5px;
    margin: 0 0 9px;
}
ul { list-style-type: none }
</style>
END_STYLE
    return qq{<html><head>${title}${style}</head><body>\n}
        . $pod->content->present($self)
        . "</body></html>\n";
}

1;

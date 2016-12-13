use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;
use JSON;

my $mech = RT::Extension::REST2::Test->mech;
my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $json = JSON->new->utf8;

sub is_404 {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $res = shift;
    is($res->code, 404);
    is($res->header('content-type'), 'application/json; charset=utf-8');
    my $content = $json->decode($res->content);
    is($content->{message}, 'Not Found');
}

# Proper 404 Response
{
    for (qw[/foobar /foo /index.html /ticket.do/1 /1/1]) {
        my $path = $rest_base_path . $_;
        is_404($mech->get($path, 'Authorization' => $auth));
        is_404($mech->post($path, { param => 'value' }, 'Authorization' => $auth));
    }
}

done_testing;

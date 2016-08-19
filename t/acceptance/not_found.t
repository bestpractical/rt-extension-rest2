use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;
use JSON;
use Try::Tiny;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $json = JSON->new->utf8;

sub check_404 {
    my $res = shift;
    is($res->code, 404);
    like($res->header('content-type'), qr{application/json});
    ok(my $data = try { $json->decode($res->content) });
    is($data->{message}, 'Not Found');
}

# Check Proper 404 Response
{
    for (qw[/foobar /foo /index.html /ticket.do/1 /1/1]) {
        my $path = $rest_base_path . $_;
        ok(my $res = $mech->get($path, 'Authorization' => $auth),
           "GET $path");
        check_404($res);

        ok($res = $mech->post(
            $path, { param => 'value' }, 'Authorization' => $auth
        ), "POST $path");
        check_404($res);
    }
}

TODO : {
    local $TODO = 'Merge endpoints';
    for (qw[/ticket /queue /user]) { # should be changed to the plural form
        my $path = $rest_base_path . $_;
        ok(my $res = $mech->get($path, 'Authorization' => $auth),
           "GET $path");
        check_404($res);

        ok($res = $mech->post(
            $path, { param => 'value' }, 'Authorization' => $auth
        ), "POST $path");
        check_404($res);
    }
}

done_testing;

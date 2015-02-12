use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;

my $rest_base_path = '/REST/2.0';

{
    ok(my $res = $mech->get($rest_base_path), "GET $rest_base_path");
    is($res->code, 401, 'Unauthorized');
    is($res->content, 'Authorization required');
    like($res->header('content-type'), qr{text/plain});
    like($res->header('www-authenticate'), qr/example\.com\s+REST\s+API/);
}

my $auth = RT::Extension::REST2::Test->authorization_header;

{
    foreach my $path (($rest_base_path, "${rest_base_path}/")) {
        $mech->get_ok($path, ['Authorization' => $auth]);
        my $res = $mech->response;
        like($res->header('content-type'), qr{text/html});
        my $content = $res->content;
        # this is a temp solution as for main doc
        # TODO: write an end user aimed documentation
        like($content, qr/RT\-Extension\-REST2/);
        like($content, qr/NAME/);
        like($content, qr/INSTALLATION/);
        like($content, qr/USAGE/);

        ok($res = $mech->head($path, 'Authorization' => $auth),
           "HEAD $path");
        is($res->code, 200);
    }
}

{
    ok(my $res = $mech->post(
        $rest_base_path, { param => 'value' }, 'Authorization' => $auth
    ), "POST $rest_base_path");
    is($res->code, 405);
    like($res->header('allow'), qr/GET|HEAD|OPTIONS/);
}

done_testing;

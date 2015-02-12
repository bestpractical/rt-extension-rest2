use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';

{
    for (qw[/foobar /foo /ticket /queue /index.html /ticket.do/1 /1/1]) {
        my $path = $rest_base_path . $_;
        ok(my $res = $mech->get($path, 'Authorization' => $auth),
           "GET $path");
        is($res->code, 404);

        ok($res = $mech->post(
            $path, { param => 'value' }, 'Authorization' => $auth
        ), "POST $path");
        is($res->code, 404);
    }
}

done_testing;

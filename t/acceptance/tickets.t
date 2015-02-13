use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;
use JSON;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $json = JSON->new->utf8;

{
    ok(my $res = $mech->get(
        $rest_base_path . '/tickets?query=id>0', 'Authorization' => $auth
    ));
    is($res->code, 400, 'DB empty, so no tickets found');
    like($res->header('content-type'), qr{application/json});
    ok(my $data = $json->decode($res->content));
    is($data->{'message'}, 'No tickets found');
}

done_testing;

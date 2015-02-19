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
    TODO : {
        local $TODO = 'Status code for no rows';
        is($res->code, 404, 'DB empty, so no tickets found');
    }
    like($res->header('content-type'), qr{application/json});
    ok(my $data = $json->decode($res->content));
    is($data->{'message'}, 'No tickets found');
}

TODO : {
    local $TODO = 'Missing param validation';
    ok(my $res = $mech->post(
        $rest_base_path . '/ticket', {}, 'Authorization' => $auth
    ));
    is($res->code, 400);
    like($res->header('content-type'), qr{application/json});
    ok(my $data = $json->decode($res->content));
    is($data->{'message'}, 'Missing required params');
}

TODO : {
    local $TODO = 'Invalid input params should respond 400';
    my $payload = $json->encode({
        Subject => 'Ticket creation using REST',
        From => 'wallace@reis.me',
    });
    ok(my $res = $mech->post(
        $rest_base_path . '/ticket',
        Content => $payload,
        'Content-Type' => 'application/json; charset=utf-8',
        'Authorization' => $auth
    ));
    is($res->code, 400);
    like($res->header('content-type'), qr{application/json});
    ok(my $data = $json->decode($res->content));
    is($data->{'message'}, 'Could not create ticket. Queue not set');
}

TODO : {
    local $TODO = 'Fix response Location URL';
    my $payload = $json->encode({
        Subject => 'Ticket creation using REST',
        From => 'wallace@reis.me',
        To => 'rt@localhost',
        Queue => 'General',
        Content => 'Testing ticket creation using REST API.',
    });
    ok(my $res = $mech->post(
        $rest_base_path . '/ticket',
        Content => $payload,
        'Content-Type' => 'application/json; charset=utf-8',
        'Authorization' => $auth
    ));
    is($res->code, 201);
    like($res->header('content-type'), qr{application/json});
    my $new_ticket_url = $res->header('location');
    like($new_ticket_url, qr[/tickets/\d+]);
    $mech->get_ok($rest_base_path . $new_ticket_url);
}

done_testing;

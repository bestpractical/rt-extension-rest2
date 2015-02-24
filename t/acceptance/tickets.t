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
    is($res->code, 404, 'DB empty, so no tickets found');
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

{
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

{
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
    ok(my $ticket_id = $new_ticket_url =~ qr[/ticket/(\d+)]);

    $mech->get_ok($rest_base_path . $new_ticket_url,
        ['Authorization' => $auth]
    );
    $res = $mech->res;
    like($res->header('content-type'), qr{application/json});
    ok(my $data = $json->decode($res->content));
    is($data->{'id'}, $ticket_id);
    is($data->{'Type'}, 'ticket');
    is($data->{'Status'}, 'new');
    is($data->{'Subject'}, 'Ticket creation using REST');
    like($data->{'_url'}, qr[/ticket/$ticket_id]);
    ok(exists $data->{$_}) for qw(AdminCc TimeEstimated Started Cc
                                  LastUpdated TimeWorked Resolved
                                  Created Due Priority EffectiveId);
    my $queue = $data->{'Queue'};
    is($queue->{'id'}, 1);
    is($queue->{'type'}, 'queue');
    like($queue->{'_url'}, qr{/queue/1});
    my $owner = $data->{'Owner'};
    is($owner->{'id'}, 'Nobody');
    is($owner->{'type'}, 'user');
    like($owner->{'_url'}, qr{/user/Nobody});
    my $creator = $data->{'Creator'};
    is($creator->{'id'}, 'root');
    is($creator->{'type'}, 'user');
    like($creator->{'_url'}, qr{/user/root});
    my $updated_by = $data->{'LastUpdatedBy'};
    is($updated_by->{'id'}, 'root');
    is($updated_by->{'type'}, 'user');
    like($updated_by->{'_url'}, qr{/user/root});
}

done_testing;

use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $json = JSON->new->utf8;
my $user = RT::Extension::REST2::Test->user;

# Empty DB
{
    my $res = $mech->get("$rest_base_path/tickets?query=id>0",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is($mech->json_response->{count}, 0);
}

# Missing Queue
{
    my $payload = $json->encode({
        Subject => 'Ticket creation using REST',
        From    => 'test@bestpractical.com',
    });
    my $res = $mech->post("$rest_base_path/ticket",
        Content         => $payload,
        'Content-Type'  => 'application/json; charset=utf-8',
        'Authorization' => $auth,
    );
    is($res->code, 400);
    is($mech->json_response->{message}, 'Could not create ticket. Queue not set');
}

# Ticket Creation
my ($ticket_url, $ticket_id);
{
    my $payload = $json->encode({
        Subject => 'Ticket creation using REST',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
    });

    # Rights Test - No CreateTicket
    my $res = $mech->post("$rest_base_path/ticket",
        'Content'       => $payload,
        'Content-Type'  => 'application/json; charset=utf-8',
        'Authorization' => $auth,
    );
    TODO: {
        local $TODO = "this should return 403";
        is($res->code, 403);
    }

    # Rights Test - With CreateTicket
    $user->PrincipalObj->GrantRight( Right => 'CreateTicket' );
    $res = $mech->post("$rest_base_path/ticket",
        'Content'       => $payload,
        'Content-Type'  => 'application/json; charset=utf-8',
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok($ticket_id = $ticket_url =~ qr[/ticket/(\d+)]);
}

# Ticket Display
{
    # Rights Test - No ShowTicket
    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 403);
}

# Rights Test - With ShowTicket
{
    $user->PrincipalObj->GrantRight( Right => 'ShowTicket' );

    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $ticket_id);
    is($content->{Type}, 'ticket');
    is($content->{Status}, 'new');
    is($content->{Subject}, 'Ticket creation using REST');
    like($content->{_url}, qr[$rest_base_path/ticket/$ticket_id$]);
    ok(exists $content->{$_}) for qw(AdminCc TimeEstimated Started Cc
                                     LastUpdated TimeWorked Resolved
                                     Created Due Priority EffectiveId);

    my $queue = $content->{Queue};
    is($queue->{id}, 1);
    is($queue->{type}, 'queue');
    like($queue->{_url}, qr{$rest_base_path/queue/1$});

    my $owner = $content->{Owner};
    is($owner->{id}, 'Nobody');
    is($owner->{type}, 'user');
    like($owner->{_url}, qr{$rest_base_path/user/Nobody$});

    my $creator = $content->{Creator};
    is($creator->{id}, 'test');
    is($creator->{type}, 'user');
    like($creator->{_url}, qr{$rest_base_path/user/test$});

    my $updated_by = $content->{LastUpdatedBy};
    is($updated_by->{id}, 'test');
    is($updated_by->{type}, 'user');
    like($updated_by->{_url}, qr{$rest_base_path/user/test$});
}

# Ticket Search
{
    my $res = $mech->get("$rest_base_path/tickets?query=id>0",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 1);
    is(scalar @{$content->{items}}, 1);

    my $ticket = $content->{items}->[0];
    is($ticket->{type}, 'ticket');
    is($ticket->{id}, 1);
    like($ticket->{_url}, qr{$rest_base_path/ticket/1$});
}

# Ticket Update
{
    my $payload = $json->encode({
        Subject  => 'Ticket update using REST',
        Priority => 42,
    });

    # Rights Test - No ModifyTicket
    my $res = $mech->put($ticket_url,
        'Content'       => $payload,
        'Content-Type'  => 'application/json; charset=utf-8',
        'Authorization' => $auth,
    );
    TODO: {
        local $TODO = "RT ->Update isn't introspectable";
        is($res->code, 403);
    };
    is_deeply($mech->json_response, ['Ticket 1: Permission Denied', 'Ticket 1: Permission Denied']);

    $user->PrincipalObj->GrantRight( Right => 'ModifyTicket' );

    $res = $mech->put($ticket_url,
        'Content'       => $payload,
        'Content-Type'  => 'application/json; charset=utf-8',
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket 1: Priority changed from (no value) to '42'", "Ticket 1: Subject changed from 'Ticket creation using REST' to 'Ticket update using REST'"]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{Subject}, 'Ticket update using REST');
    is($content->{Priority}, 42);
}

done_testing;

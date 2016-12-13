use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;
use JSON;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $json = JSON->new->utf8;
my $user = RT::Extension::REST2::Test->user;

# Empty DB
{
    ok(my $res = $mech->get(
        $rest_base_path . '/tickets?query=id>0', 'Authorization' => $auth
    ));
    like($res->header('content-type'), qr{application/json});
    ok(my $data = $json->decode($res->content));
    is($data->{count}, 0);
}

# Missing Queue
{
    my $payload = $json->encode({
        Subject => 'Ticket creation using REST',
        From => 'test@bestpractical.com',
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
    is($data->{message}, 'Could not create ticket. Queue not set');
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
    ok(my $res = $mech->post( $rest_base_path . '/ticket',
        'Content'       => $payload,
        'Content-Type'  => 'application/json; charset=utf-8',
        'Authorization' => $auth
    ));
    # TODO: This should return 403
    is($res->code, 400);

    # Rights Test - With CreateTicket
    $user->PrincipalObj->GrantRight( Right => 'CreateTicket' );
    ok($res = $mech->post( $rest_base_path . '/ticket',
        'Content'       => $payload,
        'Content-Type'  => 'application/json; charset=utf-8',
        'Authorization' => $auth
    ));
    is($res->code, 201);

    like($res->header('content-type'), qr{application/json});
    $ticket_url = $res->header('location');
    ok($ticket_id = $ticket_url =~ qr[/ticket/(\d+)]);
}

# Ticket Display
{
    # Rights Test - No ShowTicket
    $mech->get(
        $ticket_url, 'Authorization' => $auth
    );
    my $res = $mech->res;
    is($res->code, 403);

    # Rights Test - With ShowTicket
    $user->PrincipalObj->GrantRight( Right => 'ShowTicket' );
    $mech->get_ok(
        $ticket_url, [Authorization => $auth]
    );
    $res = $mech->res;
    is($res->code, 200);

    like($res->header('content-type'), qr{application/json});
    ok(my $data = $json->decode($res->content));
    is($data->{id}, $ticket_id);
    is($data->{Type}, 'ticket');
    is($data->{Status}, 'new');
    is($data->{Subject}, 'Ticket creation using REST');
    like($data->{_url}, qr[/ticket/$ticket_id]);
    ok(exists $data->{$_}) for qw(AdminCc TimeEstimated Started Cc
                                  LastUpdated TimeWorked Resolved
                                  Created Due Priority EffectiveId);
    my $queue = $data->{Queue};
    is($queue->{id}, 1);
    is($queue->{type}, 'queue');
    like($queue->{_url}, qr{/queue/1});
    my $owner = $data->{Owner};
    is($owner->{id}, 'Nobody');
    is($owner->{type}, 'user');
    like($owner->{_url}, qr{/user/Nobody});
    my $creator = $data->{Creator};
    is($creator->{id}, 'test');
    is($creator->{type}, 'user');
    like($creator->{_url}, qr{/user/test});
    my $updated_by = $data->{LastUpdatedBy};
    is($updated_by->{id}, 'test');
    is($updated_by->{type}, 'user');
    like($updated_by->{_url}, qr{/user/test});
}

# Ticket Search
{
    $mech->get_ok(
        $rest_base_path . '/tickets?query=id>0', [Authorization => $auth]
    );
    my $res = $mech->res;
    like($res->header('content-type'), qr{application/json});
    ok(my $data = $json->decode($res->content));
    is($data->{count}, 1);
    is($data->{page}, 1);
    is($data->{per_page}, 20);
    is($data->{total}, 1);
    is(scalar @{$data->{items}}, $data->{count});
}

done_testing;

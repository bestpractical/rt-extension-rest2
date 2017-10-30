use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;
use Test::Deep;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
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
    my $res = $mech->post_json("$rest_base_path/ticket",
        {
            Subject => 'Ticket creation using REST',
            From    => 'test@bestpractical.com',
        },
        'Authorization' => $auth,
    );
    is($res->code, 400);
    is($mech->json_response->{message}, 'Could not create ticket. Queue not set');
}

my $queue = RT::Test->load_or_create_queue( Name => "General" );
# Ticket Creation
my ($ticket_url, $ticket_id);
{
    my $payload = {
        Subject => 'Ticket creation using REST',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => $queue->Id,
        Content => 'Testing ticket creation using REST API.',
    };

    # Rights Test - No CreateTicket
    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403);

    # Rights Test - With CreateTicket
    $user->PrincipalObj->GrantRight( Right => 'CreateTicket' );
    $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);
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

    ok(exists $content->{$_}) for qw(AdminCc TimeEstimated Started Cc
                                     LastUpdated TimeWorked Resolved
                                     Created Due Priority EffectiveId);

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 2);

    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, 1);
    is($links->[0]{type}, 'ticket');
    like($links->[0]{_url}, qr[$rest_base_path/ticket/$ticket_id$]);

    is($links->[1]{ref}, 'history');
    like($links->[1]{_url}, qr[$rest_base_path/ticket/$ticket_id/history$]);

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
    my $payload = {
        Subject  => 'Ticket update using REST',
        Priority => 42,
    };

    # Rights Test - No ModifyTicket
    my $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    TODO: {
        local $TODO = "RT ->Update isn't introspectable";
        is($res->code, 403);
    };
    is_deeply($mech->json_response, ['Ticket 1: Permission Denied', 'Ticket 1: Permission Denied']);

    $user->PrincipalObj->GrantRight( Right => 'ModifyTicket' );

    $res = $mech->put_json($ticket_url,
        $payload,
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

    # now that we have ModifyTicket, we should have additional hypermedia
    my $links = $content->{_hyperlinks};
    is(scalar @$links, 5);

    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, 1);
    is($links->[0]{type}, 'ticket');
    like($links->[0]{_url}, qr[$rest_base_path/ticket/$ticket_id$]);

    is($links->[1]{ref}, 'history');
    like($links->[1]{_url}, qr[$rest_base_path/ticket/$ticket_id/history$]);

    is($links->[2]{ref}, 'lifecycle');
    like($links->[2]{_url}, qr[$rest_base_path/ticket/$ticket_id/correspond$]);
    is($links->[2]{label}, 'Open It');
    is($links->[2]{update}, 'Respond');
    is($links->[2]{from}, 'new');
    is($links->[2]{to}, 'open');

    is($links->[3]{ref}, 'lifecycle');
    like($links->[3]{_url}, qr[$rest_base_path/ticket/$ticket_id/comment$]);
    is($links->[3]{label}, 'Resolve');
    is($links->[3]{update}, 'Comment');
    is($links->[3]{from}, 'new');
    is($links->[3]{to}, 'resolved');

    is($links->[4]{ref}, 'lifecycle');
    like($links->[4]{_url}, qr[$rest_base_path/ticket/$ticket_id/correspond$]);
    is($links->[4]{label}, 'Reject');
    is($links->[4]{update}, 'Respond');
    is($links->[4]{from}, 'new');
    is($links->[4]{to}, 'rejected');

    # update again with no changes
    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, []);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    is($content->{Subject}, 'Ticket update using REST');
    is($content->{Priority}, 42);
}

# Transactions
{
    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $res = $mech->get($mech->url_for_hypermedia('history'),
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 3);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 3);
    is(scalar @{$content->{items}}, 3);

    for my $txn (@{ $content->{items} }) {
        is($txn->{type}, 'transaction');
        like($txn->{_url}, qr{$rest_base_path/transaction/\d+$});
    }
}

# Ticket Reply
{
    # we know from earlier tests that look at hypermedia without ReplyToTicket
    # that correspond wasn't available, so we don't need to check again here

    $user->PrincipalObj->GrantRight( Right => 'ReplyToTicket' );

    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;

    my ($hypermedia) = grep { $_->{ref} eq 'correspond' } @{ $content->{_hyperlinks} };
    ok($hypermedia, 'got correspond hypermedia');
    like($hypermedia->{_url}, qr[$rest_base_path/ticket/$ticket_id/correspond$]);

    $res = $mech->post($mech->url_for_hypermedia('correspond'),
        'Authorization' => $auth,
        'Content-Type' => 'text/plain',
        'Content' => 'Hello from hypermedia!',
    );
    is($res->code, 201);
    cmp_deeply($mech->json_response, [re(qr/Correspondence added|Message recorded/)]);

    like($res->header('Location'), qr{$rest_base_path/transaction/\d+$});
    $res = $mech->get($res->header('Location'),
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    is($content->{Type}, 'Correspond');
    is($content->{TimeTaken}, 0);
    is($content->{Object}{type}, 'ticket');
    is($content->{Object}{id}, $ticket_id);

    $res = $mech->get($mech->url_for_hypermedia('attachment'),
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    is($content->{Content}, 'Hello from hypermedia!');
    is($content->{ContentType}, 'text/plain');
}

# Ticket Comment
{
    my $payload = {
        Content     => '<i>(hello secret camera)</i>',
        ContentType => 'text/html',
        Subject     => 'shh',
        TimeTaken   => 129,
    };

    # we know from earlier tests that look at hypermedia without ReplyToTicket
    # that correspond wasn't available, so we don't need to check again here

    $user->PrincipalObj->GrantRight( Right => 'CommentOnTicket' );

    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;

    my ($hypermedia) = grep { $_->{ref} eq 'comment' } @{ $content->{_hyperlinks} };
    ok($hypermedia, 'got comment hypermedia');
    like($hypermedia->{_url}, qr[$rest_base_path/ticket/$ticket_id/comment$]);

    $res = $mech->post_json($mech->url_for_hypermedia('comment'),
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    cmp_deeply($mech->json_response, [re(qr/Comments added|Message recorded/)]);

    my $txn_url = $res->header('Location');
    like($txn_url, qr{$rest_base_path/transaction/\d+$});
    $res = $mech->get($txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 403);

    $user->PrincipalObj->GrantRight( Right => 'ShowTicketComments' );

    $res = $mech->get($txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    is($content->{Type}, 'Comment');
    is($content->{TimeTaken}, 129);
    is($content->{Object}{type}, 'ticket');
    is($content->{Object}{id}, $ticket_id);

    $res = $mech->get($mech->url_for_hypermedia('attachment'),
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    is($content->{Subject}, 'shh');
    is($content->{Content}, '<i>(hello secret camera)</i>');
    is($content->{ContentType}, 'text/html');
}

# TicketSQL AND
diag "Got correct result for  AND TicketSQL";
{
    my $res = $mech->get("$rest_base_path/tickets?query=id>0 AND Queue='General'",
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

# OR TicketSQL
# Got correct result for "OR TicketSQL"
{
  my $res = $mech->get("$rest_base_path/tickets?query=id<0 OR Queue='General'",
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

# Second Queue
$queue = RT::Test->load_or_create_queue( Name => "Two" );

# Second ticket
my ($ticket_url2, $ticket_id2);
{
    my $payload = {
        Subject => 'Ticket creation using REST',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'two',
        Content => 'Testing ticket creation using REST API.',
    };

    # Rights Test - No CreateTicket
    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url2 = $res->header('location'));
    ok(($ticket_id2) = $ticket_url2 =~ qr[/ticket/(\d+)]);
}

# Search with Multiple Tickets and Queues
diag "Got correct result for two tickets two queues";
{
    my $res = $mech->get("$rest_base_path/tickets?query=id>0 AND Queue='General'",
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

# Find both queues tickets
diag "Got correct result for two tickets two queues";
{
    my $res = $mech->get("$rest_base_path/tickets?query=Queue='Two' OR Queue='General'",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{count}, 2);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 2);
    is(scalar @{$content->{items}}, 2);

    my $ticket = $content->{items}->[0];
    is($ticket->{type}, 'ticket');
}

done_testing;

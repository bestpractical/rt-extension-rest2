use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;
my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

$user->PrincipalObj->GrantRight( Right => 'CreateTicket' );
$user->PrincipalObj->GrantRight( Right => 'ModifyTicket' );
$user->PrincipalObj->GrantRight( Right => 'ShowTicket' );

my $ticket = RT::Ticket->new($user);
$ticket->Create(Queue => 'General', Subject => 'hello world');
ok($ticket->Id, 'got an id');
$ticket->SetPriority(42);
$ticket->SetSubject('new subject');
$ticket->SetPriority(43);

# search transactions for a specific ticket
my ($create_txn_url, $create_txn_id);
{
    my $res = $mech->post_json("$rest_base_path/transactions",
        [
            { field => 'ObjectType', value => 'RT::Ticket' },
            { field => 'ObjectId', value => $ticket->Id },
        ],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 4);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 4);
    is(scalar @{$content->{items}}, 4);

    my ($create, $priority1, $subject, $priority2) = @{ $content->{items} };
    is($create->{type}, 'transaction');
    $create_txn_url = $create->{_url};
    ok(($create_txn_id) = $create_txn_url =~ qr[/transaction/(\d+)]);

    is($priority1->{type}, 'transaction');
    is($subject->{type}, 'transaction');
    is($priority2->{type}, 'transaction');
}

# Transaction display
{
    my $res = $mech->get($create_txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $create_txn_id);
    is($content->{Type}, 'Create');
    is($content->{TimeTaken}, 0);

    ok(exists $content->{$_}) for qw(Created);

    my $links = $content->{_hyperlinks};
    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $create_txn_id);
    is($links->[0]{type}, 'transaction');
    is($links->[0]{_url}, $create_txn_url);

    my $creator = $content->{Creator};
    is($creator->{id}, 'test');
    is($creator->{type}, 'user');
    like($creator->{_url}, qr{$rest_base_path/user/test$});

    my $object = $content->{Object};
    is($object->{id}, $ticket->Id);
    is($object->{type}, 'ticket');
    like($object->{_url}, qr{$rest_base_path/ticket/@{[$ticket->Id]}$});
}

# (invalid) update
{
    my $res = $mech->put_json($create_txn_url,
        { Type => 'Set' },
        'Authorization' => $auth,
    );
    is($res->code, 405);
    is($mech->json_response->{message}, 'Method Not Allowed');

    $res = $mech->get($create_txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{Type}, 'Create');
}

# (invalid) delete
{
    my $res = $mech->delete($create_txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 405);
    is($mech->json_response->{message}, 'Method Not Allowed');
}

# (invalid) create
{
    my $res = $mech->post_json("$rest_base_path/transaction",
        { Type => 'Create' },
        'Authorization' => $auth,
    );
    is($res->code, 405);
    is($mech->json_response->{message}, 'Method Not Allowed');
}

done_testing;


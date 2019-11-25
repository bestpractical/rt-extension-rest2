use strict;
use warnings;
use RT::Extension::REST2::Test tests => undef;
use Test::Deep;

my $mech = RT::Extension::REST2::Test->mech;
my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

$user->PrincipalObj->GrantRight( Right => 'CreateTicket' );
$user->PrincipalObj->GrantRight( Right => 'ModifyTicket' );
$user->PrincipalObj->GrantRight( Right => 'ReplyToTicket' );
$user->PrincipalObj->GrantRight( Right => 'SeeQueue' );
$user->PrincipalObj->GrantRight( Right => 'ShowTicket' );
$user->PrincipalObj->GrantRight( Right => 'ShowTicketComments' );
$user->PrincipalObj->GrantRight( Right => 'SeeCustomField' );
$user->PrincipalObj->GrantRight( Right => 'ModifyCustomField' );

my $single_cf = RT::CustomField->new( RT->SystemUser );
my ($ok, $msg) = $single_cf->Create( Name => 'Single', Type => 'FreeformSingle', LookupType => RT::Transaction->CustomFieldLookupType);
ok($ok, $msg);

my $queue = RT::Test->load_or_create_queue( Name => "General" );
my $single_cf_id;
($single_cf_id,$msg) = $single_cf->AddToObject($queue);
ok($single_cf_id, $msg);

my ($ticket_url, $ticket_id);
{
    my $payload = {
        Subject => 'Ticket for CF test',
        Queue   => 'General',
        Content => 'Ticket for CF test content',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    # We need the hypermedia URLs...
    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $payload = {
        Subject => 'Add Txn with CF',
        Content => 'Content',
        ContentType => 'text/plain',
        'TxnCustomFields' => {
            'Single' => 'Txn CustomField',
         },
    };

    $res = $mech->post_json($mech->url_for_hypermedia('correspond'),
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    cmp_deeply($mech->json_response, [re(qr/Correspondence added|Message recorded/)]);
}

# Look for the Transaction with our CustomField set.
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

    # Check the correspond txn (0 = create, 1 = correspond)
    my $txn = @{ $content->{items} }[1];

    $res = $mech->get($txn->{_url},
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    like($content->{Data}, qr/^Add Txn with CF/);

    cmp_deeply($content->{CustomFields}{$single_cf_id}, ['Txn CustomField']);
}

done_testing;


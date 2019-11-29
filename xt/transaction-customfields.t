use strict;
use warnings;
use RT::Extension::REST2::Test tests => undef;
use Test::Deep;

my $mech = RT::Extension::REST2::Test->mech;
my ( $baseurl, $m ) = RT::Test->started_ok;
diag "Started server at $baseurl";

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $admin = RT::Extension::REST2::Test->user;
$admin->PrincipalObj->GrantRight( Right => 'SuperUser' );

my $queue = RT::Test->load_or_create_queue( Name => "General" );

my( $id, $msg);

my $cf = RT::CustomField->new( RT->SystemUser );
my $cfid;
($cfid, $msg) = $cf->Create(Name => 'TxnCF', Type => 'FreeformSingle', MaxValues => '0', LookupType => RT::Transaction->CustomFieldLookupType );
ok($cfid,$msg);

($id,$msg) = $cf->AddToObject($queue);
ok($id,$msg);

my $ticket = RT::Ticket->new(RT->SystemUser);
my ( $ticket1_id, $transid );
($ticket1_id, $transid, $msg) = $ticket->Create(Queue => $queue->id, Subject => 'TxnCF test',);
ok( $ticket1_id, $msg );

my $res = $mech->get("$rest_base_path/ticket/$ticket1_id", 'Authorization' => $auth);
is( $res->code, 200, 'Fetched ticket via REST2 API');

{
    my $payload = { Content         => "reply one",
                    ContentType     => "text/plain",
                    TxnCustomFields => { "TxnCF" => "txncf value one"},
                  };
    my $res = $mech->post_json("$rest_base_path/ticket/$ticket1_id/correspond", $payload, 'Authorization' => $auth);
    is( $res->code, 201, 'correspond response code is 201');
    is_deeply( $mech->json_response, [ "Correspondence added", "Custom fields updated" ], 'message is "Correspondence Added"');

    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ( $ret, $msg ) = $ticket->Load( $ticket1_id );
    ok( $ret, $msg );
    my $txns = $ticket->Transactions;
    $txns->Limit( FIELD => 'Type', VALUE => 'Correspond' );
    my $txn = $txns->Last;
    ok( $txn->Id, "Found Correspond transaction" );
    is( $txn->FirstCustomFieldValue('TxnCF'), "txncf value one", 'Found transaction custom field');
}

# TODO Determine how to use RT::Test::Web tools to check and clear expected warnings

=pod

{
    my $payload = { Content         => "reply two",
                    ContentType     => "text/plain",
                    TxnCustomFields => { "not a real CF name" => "txncf value"},
                  };
    my $res = $mech->post_json("$rest_base_path/ticket/$ticket1_id/correspond", $payload, 'Authorization' => $auth);

    # Doesn't work like RT
    my @warnings = $m->get_warnings;

    is( $res->code, 201, 'Correspond response code is 201 because correspond succeeded');
    is( $mech->json_response, [ "Correspondence added - CF Processing Error: transaction custom fields not updated" ], 'Bogus cf name');
}

=cut

done_testing();

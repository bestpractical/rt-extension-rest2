use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

$user->PrincipalObj->GrantRight( Right => $_ )
    for qw/CreateTicket ShowTicket ModifyTicket/;

# Create and update a ticket without conflicts
{
    my ($ticket_url, $ticket_id);
    my $payload = {
        Subject => 'Version 1',
        Queue   => 'General',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is($mech->json_response->{Subject}, 'Version 1');
    my $etag = $res->header('ETag');
    ok($etag, "got an ETag");

    $payload = {
        Subject => 'Version 2',
    };
    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
        'If-Match' => $etag,
    );
    is($res->code, 200);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is($mech->json_response->{Subject}, 'Version 2');
    $etag = $res->header('ETag');
    ok($etag, "got an ETag");

    $payload = {
        Subject => 'Version 3',
    };
    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
        'If-Match' => $etag,
    );
    is($res->code, 200);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is($mech->json_response->{Subject}, 'Version 3');
    $etag = $res->header('ETag');
    ok($etag, "got an ETag");
}

# Create and update a ticket with conflicts
{
    my ($ticket_url, $ticket_id);
    my $payload = {
        Subject => 'Version 1',
        Queue   => 'General',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is($mech->json_response->{Subject}, 'Version 1');
    my $first_etag = $res->header('ETag');
    ok($first_etag, "got an ETag");

    $payload = {
        Subject => 'Version 2',
    };
    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
        'If-Match' => $first_etag,
    );
    is($res->code, 200);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is($mech->json_response->{Subject}, 'Version 2');
    my $second_etag = $res->header('ETag');
    ok($second_etag, "got an ETag");

    $payload = {
        Subject => 'Version 3',
    };
    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
        'If-Match' => $first_etag, # <-- note old etag use
    );
    is($res->code, 412);
    is($mech->json_response->{message}, 'Precondition Failed');

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is($mech->json_response->{Subject}, 'Version 2');
    my $third_etag = $res->header('ETag');
    ok($third_etag, "got an ETag");
    is($third_etag, $second_etag, "ETag is unchanged from the previous one");

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
        # no If-Match header
    );
    is($res->code, 200);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is($mech->json_response->{Subject}, 'Version 3');
    my $fourth_etag = $res->header('ETag');
    ok($fourth_etag, "got an ETag");

}
done_testing;

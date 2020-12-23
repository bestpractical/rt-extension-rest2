use strict;
use warnings;
use RT::Extension::REST2::Test tests => undef;
use Test::Deep;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;


diag 'Check validation on create';
my ($ticket_url, $ticket_id);
{
    $user->PrincipalObj->GrantRight( Right => 'CreateTicket' );
    my $payload = {
        Subject => 'Ticket creation using REST',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
        VALIDATE => 'BAD_CREATE!',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 400, 'Validation returned 400');

    # Do a successful create for later test
    $payload = {
        Subject => 'Ticket creation using REST',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
    };

    $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);
}

# Ticket Update
{
    my $payload = {
        Subject  => 'Ticket update using REST',
        Priority => 42,
        VALIDATE => 'BAD_UPDATE!',
    };

    $user->PrincipalObj->GrantRight( Right => 'ShowTicket' );
    $user->PrincipalObj->GrantRight( Right => 'ModifyTicket' );

    my $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 400, 'Validation returned 400');
}


done_testing;

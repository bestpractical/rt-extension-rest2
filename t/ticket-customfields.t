use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

my $queue = RT::Test->load_or_create_queue( Name => "General" );

my $cf = RT::CustomField->new( RT->SystemUser );
$cf->Create( Name => 'Freeform', Type => 'FreeformSingle', Queue => $queue->Id );

# Ticket Creation with no ModifyCustomField
my ($ticket_url, $ticket_id);
{
    my $payload = {
        Subject => 'Ticket creation using REST',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
        'CustomField-' . $cf->Id => 'Hello world!',
    };

    # Rights Test - No CreateTicket
    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    TODO: {
        local $TODO = "this should return 403";
        is($res->code, 403);
    }

    my @warnings;
    local $SIG{__WARN__} = sub {
        push @warnings, @_;
    };

    # Rights Test - With CreateTicket
    $user->PrincipalObj->GrantRight( Right => 'CreateTicket' );
    $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

   TODO: {
       local $TODO = "this warns due to specifying a CF with no permission to see";
       is(@warnings, 0, "no warnings");
   }
}

# Ticket Display
{
    # Rights Test - No ShowTicket
    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 403);
}

# Rights Test - With ShowTicket but no SeeCustomField
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
    is_deeply($content->{'CF.Freeform'}, undef, 'Ticket custom field not present');
}

# Rights Test - With ShowTicket and SeeCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField', Object => $cf);

    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $ticket_id);
    is($content->{Type}, 'ticket');
    is($content->{Status}, 'new');
    is($content->{Subject}, 'Ticket creation using REST');
    is_deeply($content->{'CF.Freeform'}, [], 'Ticket custom field');
}

# Ticket Creation with ModifyCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'ModifyCustomField', Object => $cf);

    my $payload = {
        Subject => 'Ticket creation using REST',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
        'CustomField-' . $cf->Id => 'Hello world!',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);
}

# Rights Test - With ShowTicket and SeeCustomField
{
    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $ticket_id);
    is($content->{Type}, 'ticket');
    is($content->{Status}, 'new');
    is($content->{Subject}, 'Ticket creation using REST');
    is_deeply($content->{'CF.Freeform'}, ['Hello world!'], 'Ticket custom field');
}

done_testing;


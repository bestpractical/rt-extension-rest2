use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;
use Test::Deep;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

my $queue = RT::Test->load_or_create_queue( Name => "General" );

$user->PrincipalObj->GrantRight( Right => $_ )
    for qw/CreateTicket ShowTicket ModifyTicket OwnTicket AdminUsers/;

# Create and view ticket with no watchers
{
    my $payload = {
        Subject => 'Ticket with no watchers',
        Queue   => 'General',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok(my $ticket_url = $res->header('location'));
    ok((my $ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    cmp_deeply($content->{Requestor}, [], 'no Requestor');
    cmp_deeply($content->{Cc}, [], 'no Cc');
    cmp_deeply($content->{AdminCc}, [], 'no AdminCc');
    cmp_deeply($content->{Owner}, {
        type => 'user',
        id   => 'Nobody',
        _url => re(qr{$rest_base_path/user/Nobody$}),
    }, 'Owner is Nobody');

    $res = $mech->get($content->{Owner}{_url},
        'Authorization' => $auth,
    );
    is($res->code, 200);
    cmp_deeply($mech->json_response, superhashof({
        id => RT->Nobody->id,
        Name => 'Nobody',
        RealName => 'Nobody in particular',
    }), 'Nobody user');
}

# Create and view ticket with single users as watchers
{
    my $payload = {
        Subject   => 'Ticket with single watchers',
        Queue     => 'General',
        Requestor => 'requestor@example.com',
        Cc        => 'cc@example.com',
        AdminCc   => 'admincc@example.com',
        Owner     => $user->EmailAddress,
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok(my $ticket_url = $res->header('location'));
    ok((my $ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    cmp_deeply($content->{Requestor}, [{
        type => 'user',
        id   => 'requestor@example.com',
        _url => re(qr{$rest_base_path/user/requestor\@example\.com$}),
    }], 'one Requestor');

    cmp_deeply($content->{Cc}, [{
        type => 'user',
        id   => 'cc@example.com',
        _url => re(qr{$rest_base_path/user/cc\@example\.com$}),
    }], 'one Cc');

    cmp_deeply($content->{AdminCc}, [{
        type => 'user',
        id   => 'admincc@example.com',
        _url => re(qr{$rest_base_path/user/admincc\@example\.com$}),
    }], 'one AdminCc');

    cmp_deeply($content->{Owner}, {
        type => 'user',
        id   => 'test',
        _url => re(qr{$rest_base_path/user/test$}),
    }, 'Owner is REST test user');
}

# Create and view ticket with multiple users as watchers
{
    my $payload = {
        Subject   => 'Ticket with multiple watchers',
        Queue     => 'General',
        Requestor => ['requestor@example.com', 'requestor2@example.com'],
        Cc        => ['cc@example.com', 'cc2@example.com'],
        AdminCc   => ['admincc@example.com', 'admincc2@example.com'],
        Owner     => $user->EmailAddress,
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok(my $ticket_url = $res->header('location'));
    ok((my $ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    cmp_deeply($content->{Requestor}, [{
        type => 'user',
        id   => 'requestor@example.com',
        _url => re(qr{$rest_base_path/user/requestor\@example\.com$}),
    }, {
        type => 'user',
        id   => 'requestor2@example.com',
        _url => re(qr{$rest_base_path/user/requestor2\@example\.com$}),
    }], 'two Requestors');

    cmp_deeply($content->{Cc}, [{
        type => 'user',
        id   => 'cc@example.com',
        _url => re(qr{$rest_base_path/user/cc\@example\.com$}),
    }, {
        type => 'user',
        id   => 'cc2@example.com',
        _url => re(qr{$rest_base_path/user/cc2\@example\.com$}),
    }], 'two Ccs');

    cmp_deeply($content->{AdminCc}, [{
        type => 'user',
        id   => 'admincc@example.com',
        _url => re(qr{$rest_base_path/user/admincc\@example\.com$}),
    }, {
        type => 'user',
        id   => 'admincc2@example.com',
        _url => re(qr{$rest_base_path/user/admincc2\@example\.com$}),
    }], 'two AdminCcs');

    cmp_deeply($content->{Owner}, {
        type => 'user',
        id   => 'test',
        _url => re(qr{$rest_base_path/user/test$}),
    }, 'Owner is REST test user');
}

# Modify owner
{
    my $payload = {
        Subject   => 'Ticket for modifying owner',
        Queue     => 'General',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok(my $ticket_url = $res->header('location'));
    ok((my $ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    cmp_deeply($mech->json_response->{Owner}, {
        type => 'user',
        id   => 'Nobody',
        _url => re(qr{$rest_base_path/user/Nobody$}),
    }, 'Owner is Nobody');

    for my $identifier ($user->id, $user->Name) {
        $payload = {
            Owner => $identifier,
        };

        $res = $mech->put_json($ticket_url,
            $payload,
            'Authorization' => $auth,
        );
        is_deeply($mech->json_response, ["Ticket $ticket_id: Owner changed from Nobody to test"], "updated Owner with identifier $identifier");

        $res = $mech->get($ticket_url,
            'Authorization' => $auth,
        );
        is($res->code, 200);

        cmp_deeply($mech->json_response->{Owner}, {
            type => 'user',
            id   => 'test',
            _url => re(qr{$rest_base_path/user/test$}),
        }, 'Owner has changed to test');

        $payload = {
            Owner => 'Nobody',
        };

        $res = $mech->put_json($ticket_url,
            $payload,
            'Authorization' => $auth,
        );
        is_deeply($mech->json_response, ["Ticket $ticket_id: Owner changed from test to Nobody"], 'updated Owner');

        $res = $mech->get($ticket_url,
            'Authorization' => $auth,
        );
        is($res->code, 200);

        cmp_deeply($mech->json_response->{Owner}, {
            type => 'user',
            id   => 'Nobody',
            _url => re(qr{$rest_base_path/user/Nobody$}),
        }, 'Owner has changed to Nobody');
    }
}

done_testing;


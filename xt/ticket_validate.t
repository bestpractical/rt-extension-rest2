use strict;
use warnings;
use RT::Extension::REST2::Test tests => undef;
use Test::Deep;
my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

sub my_create_validator
{
    my ($queue, $data) = @_;
    if ($data->{VALIDATE} && $data->{VALIDATE} eq 'BAD_CREATE!') {
        return (0, 'Bad data');
    }
    return (1, '');
}

sub my_update_validator
{
    my ($ticket, $data) = @_;
    if ( $data->{'VALIDATE'} and $data->{'VALIDATE'} eq 'BAD_UPDATE!' ) {
        return (0, 'Bad data');
    }

    return (1, '');
}

ok(RT::Extension::REST2->add_validation_hook('create', 'RT::Ticket', sub { return my_create_validator(@_); }), 'Successfully added ticket-create validation hook');
ok(RT::Extension::REST2->add_validation_hook('update', 'RT::Ticket', sub { return my_update_validator(@_); }), 'Successfully added ticket-update validation hook');

ok(!RT::Extension::REST2->add_validation_hook('update', 'RT::NOPE', sub { return my_update_validator(@_); }), 'Correctly failed to add validation hook for unknown object type');

ok(!RT::Extension::REST2->add_validation_hook('migrate', 'RT::Ticket', sub { return my_update_validator(@_); }), 'Correctly failed to add validation hook for unknown modification type');

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
    {
        no warnings;
        *RT::Extension::REST2::Resource::Ticket::validate_hook_before_create = *RT::Extension::REST2::TestValidate::validate_hook_before_create;
        *RT::Extension::REST2::Resource::Ticket::validate_hook_before_update = *RT::Extension::REST2::TestValidate::validate_hook_before_update;
    }

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
    is($res->code, 200, 'Validation returned 200');
    cmp_deeply($mech->json_response, [0, 'Bad data'], "Validation error is indicated by JSON response");

}


done_testing;

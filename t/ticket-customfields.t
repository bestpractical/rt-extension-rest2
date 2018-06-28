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

my $single_cf = RT::CustomField->new( RT->SystemUser );
my ($ok, $msg) = $single_cf->Create( Name => 'Single', Type => 'FreeformSingle', Queue => $queue->Id );
ok($ok, $msg);
my $single_cf_id = $single_cf->Id;

my $multi_cf = RT::CustomField->new( RT->SystemUser );
($ok, $msg) = $multi_cf->Create( Name => 'Multi', Type => 'FreeformMultiple', Queue => $queue->Id );
ok($ok, $msg);
my $multi_cf_id = $multi_cf->Id;

# Ticket Creation with no ModifyCustomField
my ($ticket_url, $ticket_id);
{
    my $payload = {
        Subject => 'Ticket creation using REST',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
        CustomFields => {
            $single_cf_id => 'Hello world!',
        },
    };

    # 4.2.3 introduced a bug (e092e23) in CFs fixed in 4.2.9 (ab7ea15)
    delete $payload->{CustomFields}
        if RT::Handle::cmp_version($RT::VERSION, '4.2.3') >= 0
        && RT::Handle::cmp_version($RT::VERSION, '4.2.8') <= 0;

    # Rights Test - No CreateTicket
    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403);

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
       local $TODO = "this warns due to specifying a CF with no permission to see" if RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
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
    is_deeply($content->{'CustomFields'}, [], 'Ticket custom field not present');
    is_deeply([grep { $_->{ref} eq 'customfield' } @{ $content->{'_hyperlinks'} }], [], 'No CF hypermedia');
}

my $no_ticket_cf_values = bag(
  { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => [] },
  { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
);

# Rights Test - With ShowTicket and SeeCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField');

    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $ticket_id);
    is($content->{Type}, 'ticket');
    is($content->{Status}, 'new');
    is($content->{Subject}, 'Ticket creation using REST');
    cmp_deeply($content->{CustomFields}, $no_ticket_cf_values, 'No ticket custom field values');
    cmp_deeply(
        [grep { $_->{ref} eq 'customfield' } @{ $content->{'_hyperlinks'} }],
        [{
            ref => 'customfield',
            id  => $single_cf_id,
            type => 'customfield',
            _url => re(qr[$rest_base_path/customfield/$single_cf_id$]),
        }, {
            ref => 'customfield',
            id  => $multi_cf_id,
            type => 'customfield',
            _url => re(qr[$rest_base_path/customfield/$multi_cf_id$]),
        }],
        'Two CF hypermedia',
    );

    my ($single_url) = map { $_->{_url} } grep { $_->{ref} eq 'customfield' && $_->{id} == $single_cf_id } @{ $content->{'_hyperlinks'} };
    my ($multi_url) = map { $_->{_url} } grep { $_->{ref} eq 'customfield' && $_->{id} == $multi_cf_id } @{ $content->{'_hyperlinks'} };

    $res = $mech->get($single_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    cmp_deeply($mech->json_response, superhashof({
        id         => $single_cf_id,
        Disabled   => 0,
        LookupType => RT::Ticket->CustomFieldLookupType,
        MaxValues  => 1,
	Name       => 'Single',
	Type       => 'Freeform',
    }), 'single cf');

    $res = $mech->get($multi_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    cmp_deeply($mech->json_response, superhashof({
        id         => $multi_cf_id,
        Disabled   => 0,
        LookupType => RT::Ticket->CustomFieldLookupType,
        MaxValues  => 0,
	Name       => 'Multi',
	Type       => 'Freeform',
    }), 'multi cf');
}

# Ticket Update without ModifyCustomField
{
    my $payload = {
        Subject  => 'Ticket update using REST',
        Priority => 42,
        CustomFields => {
            $single_cf_id => 'Modified CF',
        },
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
    is_deeply($mech->json_response, ['Ticket 1: Permission Denied', 'Ticket 1: Permission Denied', 'Could not add new custom field value: Permission Denied']);

    $user->PrincipalObj->GrantRight( Right => 'ModifyTicket' );

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket 1: Priority changed from (no value) to '42'", "Ticket 1: Subject changed from 'Ticket creation using REST' to 'Ticket update using REST'", 'Could not add new custom field value: Permission Denied']);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{Subject}, 'Ticket update using REST');
    is($content->{Priority}, 42);
    cmp_deeply($content->{CustomFields}, $no_ticket_cf_values, 'No update to CF');
}

# Ticket Update with ModifyCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'ModifyCustomField' );
    my $payload = {
        Subject  => 'More updates using REST',
        Priority => 43,
        CustomFields => {
            $single_cf_id => 'Modified CF',
        },
    };
    my $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket 1: Priority changed from '42' to '43'", "Ticket 1: Subject changed from 'Ticket update using REST' to 'More updates using REST'", 'Single Modified CF added']);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $modified_single_cf_value = bag(
        { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Modified CF'] },
        { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );

    my $content = $mech->json_response;
    is($content->{Subject}, 'More updates using REST');
    is($content->{Priority}, 43);
    cmp_deeply($content->{CustomFields}, $modified_single_cf_value, 'New CF value');

    # make sure changing the CF doesn't add a second OCFV
    $payload->{CustomFields}{$single_cf_id} = 'Modified Again';
    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ['Single Modified CF changed to Modified Again']);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $modified_again_single_cf_value = bag(
        { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Modified Again'] },
        { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );

    $content = $mech->json_response;
    cmp_deeply($content->{CustomFields}, $modified_again_single_cf_value, 'New CF value');

    # stop changing the CF, change something else, make sure CF sticks around
    delete $payload->{CustomFields}{$single_cf_id};
    $payload->{Subject} = 'No CF change';
    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket 1: Subject changed from 'More updates using REST' to 'No CF change'"]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    cmp_deeply($content->{CustomFields}, $modified_again_single_cf_value, 'Same CF value');
}

# Ticket Creation with ModifyCustomField
{
    my $payload = {
        Subject => 'Ticket creation using REST',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
        CustomFields => {
            $single_cf_id => 'Hello world!',
        },
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

    my $ticket_cf_value = bag(
        { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Hello world!'] },
        { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );

    my $content = $mech->json_response;
    is($content->{id}, $ticket_id);
    is($content->{Type}, 'ticket');
    is($content->{Status}, 'new');
    is($content->{Subject}, 'Ticket creation using REST');
    cmp_deeply($content->{CustomFields}, $ticket_cf_value, 'Ticket custom field');
}

# Ticket Creation for multi-value CF
for my $value (
    'scalar',
    ['array reference'],
    ['multiple', 'values'],
) {
    my $payload = {
        Subject => 'Multi-value CF',
        Queue   => 'General',
        CustomFields => {
            $multi_cf_id => $value,
        },
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

    my $content = $mech->json_response;
    is($content->{id}, $ticket_id);
    is($content->{Type}, 'ticket');
    is($content->{Status}, 'new');
    is($content->{Subject}, 'Multi-value CF');

    my $output = ref($value) ? $value : [$value]; # scalar input comes out as array reference
    my $ticket_cf_value = bag(
        { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => [] },
        { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => $output },
    );
    cmp_deeply($content->{'CustomFields'}, $ticket_cf_value, 'Ticket custom field');
}

{
    sub modify_multi_ok {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        my $input = shift;
        my $messages = shift;
        my $output = shift;
        my $name = shift;

        my $payload = {
            CustomFields => {
                $multi_cf_id => $input,
            },
        };
        my $res = $mech->put_json($ticket_url,
            $payload,
            'Authorization' => $auth,
        );
        is($res->code, 200);
        is_deeply($mech->json_response, $messages);

        $res = $mech->get($ticket_url,
            'Authorization' => $auth,
        );
        is($res->code, 200);

        my $ticket_cf_value = bag(
            { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => [] },
            { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => bag(@$output) },
        );

        my $content = $mech->json_response;
        cmp_deeply($content->{'CustomFields'}, $ticket_cf_value, $name || 'New CF value');
    }

    # starting point: ['multiple', 'values'],
    modify_multi_ok(['multiple', 'values'], [], ['multiple', 'values'], 'no change');
    modify_multi_ok(['multiple', 'values', 'new'], ['new added as a value for Multi'], ['multiple', 'new', 'values'], 'added "new"');
    modify_multi_ok(['multiple', 'new'], ['values is no longer a value for custom field Multi'], ['multiple', 'new'], 'removed "values"');
    modify_multi_ok('replace all', ['replace all added as a value for Multi', 'multiple is no longer a value for custom field Multi', 'new is no longer a value for custom field Multi'], ['replace all'], 'replaced all values');
    modify_multi_ok([], ['replace all is no longer a value for custom field Multi'], [], 'removed all values');

    if (RT::Handle::cmp_version($RT::VERSION, '4.2.5') >= 0) {
        modify_multi_ok(['foo', 'foo', 'bar'], ['foo added as a value for Multi', undef, 'bar added as a value for Multi'], ['bar', 'foo'], 'multiple values with the same name');
        modify_multi_ok(['foo', 'bar'], [], ['bar', 'foo'], 'multiple values with the same name');
        modify_multi_ok(['bar'], ['foo is no longer a value for custom field Multi'], ['bar'], 'multiple values with the same name');
        modify_multi_ok(['bar', 'bar', 'bar'], [undef, undef], ['bar'], 'multiple values with the same name');
    } else {
        modify_multi_ok(['foo', 'foo', 'bar'], ['foo added as a value for Multi', 'foo added as a value for Multi', 'bar added as a value for Multi'], ['bar', 'foo', 'foo'], 'multiple values with the same name');
        modify_multi_ok(['foo', 'bar'], ['foo is no longer a value for custom field Multi'], ['bar', 'foo'], 'multiple values with the same name');
        modify_multi_ok(['bar'], ['foo is no longer a value for custom field Multi'], ['bar'], 'multiple values with the same name');
        modify_multi_ok(['bar', 'bar', 'bar'], ['bar added as a value for Multi', 'bar added as a value for Multi'], ['bar', 'bar', 'bar'], 'multiple values with the same name');
    }
}

done_testing;


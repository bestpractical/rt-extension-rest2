use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;
my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

# Right test - create customfield without SeeCustomField nor AdminCustomField
{
    my $payload = {
        Name      => 'Freeform CF',
        Type      => 'Freeform',
        MaxValues => 1,
    };
    my $res = $mech->post_json("$rest_base_path/customfield",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403);
    is($res->message, 'Forbidden');

    my $freeform_cf = RT::CustomField->new(RT->SystemUser);
    my ($ok, $msg) = $freeform_cf->Load('Freeform CF');
    is($freeform_cf->id, undef);
    ok(!$ok);
    is($msg, 'Not found');
}

# Customfield create
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField' );
    $user->PrincipalObj->GrantRight( Right => 'AdminCustomField' );
    my $payload = {
        Name       => 'Freeform CF',
        Type       => 'Freeform',
        LookupType => 'RT::Queue-RT::Ticket',
        MaxValues  => 1,
    };
    my $res = $mech->post_json("$rest_base_path/customfield",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);

    my $freeform_cf = RT::CustomField->new(RT->SystemUser);
    $freeform_cf->Load('Freeform CF');
    is($freeform_cf->id, 2);
    is($freeform_cf->Description, '');
}

# Right test - search ticket customfields without SeeCustomField
{
    $user->PrincipalObj->RevokeRight( Right => 'SeeCustomField' );

    my $res = $mech->post_json("$rest_base_path/customfields",
        [{field => 'LookupType', value => 'RT::Queue-RT::Ticket'}],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{total}, 1);
    is($content->{count}, 0);
    is_deeply($content->{items}, []);
}

# Search ticket customfields
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField' );

    my $res = $mech->post_json("$rest_base_path/customfields",
        [{field => 'LookupType', value => 'RT::Queue-RT::Ticket'}],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{total}, 1);
    is($content->{count}, 1);
    is(scalar(@{$content->{items}}), 1);
    is(scalar(keys %{$content->{items}->[0]}), 3);
    is($content->{items}->[0]->{type}, 'customfield');
    is($content->{items}->[0]->{id}, 2);
    like($content->{items}->[0]->{_url}, qr{$rest_base_path/customfield/2$});
}

# Right test - display customfield without SeeCustomField
{
    $user->PrincipalObj->RevokeRight( Right => 'SeeCustomField' );

    my $res = $mech->get("$rest_base_path/customfield/2",
        'Authorization' => $auth,
    );
    is($res->code, 403);
}

# Display customfield 
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField' );

    my $res = $mech->get("$rest_base_path/customfield/2",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{id}, 2);
    is($content->{Name}, 'Freeform CF');
    is($content->{Description}, '');
    is($content->{LookupType}, 'RT::Queue-RT::Ticket');
    is($content->{Type}, 'Freeform');
    is($content->{MaxValues}, 1);
    is($content->{Disabled}, 0);

    my @fields = qw(SortOrder Pattern Created Creator LastUpdated LastUpdatedBy);
    push @fields, qw(UniqueValues EntryHint) if RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
    ok(exists $content->{$_}, "got $_") for @fields;

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 1);
    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, 2);
    is($links->[0]{type}, 'customfield');
    like($links->[0]{_url}, qr{$rest_base_path/customfield/2$});
}

# Right test - update customfield without AdminCustomField
{
    $user->PrincipalObj->RevokeRight( Right => 'AdminCustomField' );

    my $payload = {
        Description  => 'This is a CF for testing REST CRUD on CFs',
    };
    my $res = $mech->put_json("$rest_base_path/customfield/2",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403);
    is($res->message, 'Forbidden');
}

# Update customfield
{
    $user->PrincipalObj->GrantRight( Right => 'AdminCustomField' );

    my $payload = {
        Description  => 'This is a CF for testing REST CRUD on CFs',
    };
    my $res = $mech->put_json("$rest_base_path/customfield/2",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $freeform_cf = RT::CustomField->new(RT->SystemUser);
    $freeform_cf->Load('Freeform CF');
    is($freeform_cf->id, 2);
    is($freeform_cf->Description, 'This is a CF for testing REST CRUD on CFs');
}

# Right test - delete customfield without AdminCustomField
{
    $user->PrincipalObj->RevokeRight( Right => 'AdminCustomField' );

    my $res = $mech->delete("$rest_base_path/customfield/2",
        'Authorization' => $auth,
    );
    is($res->code, 403);
    is($res->message, 'Forbidden');

    my $freeform_cf = RT::CustomField->new(RT->SystemUser);
    $freeform_cf->Load('Freeform CF');
    is($freeform_cf->Disabled, 0);
}

# Delete customfield
{
    $user->PrincipalObj->GrantRight( Right => 'AdminCustomField' );

    my $res = $mech->delete("$rest_base_path/customfield/2",
        'Authorization' => $auth,
    );
    is($res->code, 204);

    my $freeform_cf = RT::CustomField->new(RT->SystemUser);
    $freeform_cf->Load('Freeform CF');
    is($freeform_cf->Disabled, 1);
}

done_testing;


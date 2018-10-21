use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;
my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

my $freeform_cf = RT::CustomField->new(RT->SystemUser);
$freeform_cf->Create(Name => 'Freeform CF', Type => 'Freeform', MaxValues => 1, Queue => 'General');
my $freeform_cf_id = $freeform_cf->id;

my $select_cf = RT::CustomField->new(RT->SystemUser);
$select_cf->Create(Name => 'Select CF', Type => 'Select', MaxValues => 1, Queue => 'General');
$select_cf->AddValue(Name => 'First Value', SortOder => 0);
$select_cf->AddValue(Name => 'Second Value', SortOrder => 1);
$select_cf->AddValue(Name => 'Third Value', SortOrder => 2);
my $select_cf_id = $select_cf->id;
my $select_cf_values = $select_cf->Values->ItemsArrayRef;

my $basedon_cf = RT::CustomField->new(RT->SystemUser);
$basedon_cf->Create(Name => 'SubSelect CF', Type => 'Select', MaxValues => 1, Queue => 'General', BasedOn => $select_cf->id);
$basedon_cf->AddValue(Name => 'With First Value', Category => $select_cf_values->[0]->Name, SortOder => 0);
$basedon_cf->AddValue(Name => 'With No Value', SortOder => 0);
my $basedon_cf_id = $basedon_cf->id;
my $basedon_cf_values = $basedon_cf->Values->ItemsArrayRef;

# Right test - search all tickets customfields without SeeCustomField
{
    my $res = $mech->post_json("$rest_base_path/customfields",
        [{field => 'LookupType', value => 'RT::Queue-RT::Ticket'}],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{total}, 3);
    is($content->{count}, 0);
    is_deeply($content->{items}, []);
}

# search all tickets customfields
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField' );

    my $res = $mech->post_json("$rest_base_path/customfields",
        [{field => 'LookupType', value => 'RT::Queue-RT::Ticket'}],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{total}, 3);
    is($content->{count}, 3);
    my $items = $content->{items};
    is(scalar(@$items), 3);
    
    is($items->[0]->{type}, 'customfield');
    is($items->[0]->{id}, $freeform_cf->id);
    like($items->[0]->{_url}, qr{$rest_base_path/customfield/$freeform_cf_id$});

    is($items->[1]->{type}, 'customfield');
    is($items->[1]->{id}, $select_cf->id);
    like($items->[1]->{_url}, qr{$rest_base_path/customfield/$select_cf_id$});

    is($items->[2]->{type}, 'customfield');
    is($items->[2]->{id}, $basedon_cf->id);
    like($items->[2]->{_url}, qr{$rest_base_path/customfield/$basedon_cf_id$});
}

# Freeform CustomField display
{
    my $res = $mech->get("$rest_base_path/customfield/$freeform_cf_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{id}, $freeform_cf_id);
    is($content->{Name}, $freeform_cf->Name);
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
    is($links->[0]{id}, $freeform_cf_id);
    is($links->[0]{type}, 'customfield');
    like($links->[0]{_url}, qr{$rest_base_path/customfield/$freeform_cf_id$});
}

# Select CustomField display
{
    my $res = $mech->get("$rest_base_path/customfield/$select_cf_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{id}, $select_cf_id);
    is($content->{Name}, $select_cf->Name);
    is($content->{Description}, '');
    is($content->{LookupType}, 'RT::Queue-RT::Ticket');
    is($content->{Type}, 'Select');
    is($content->{MaxValues}, 1);
    is($content->{Disabled}, 0);

    my @fields = qw(SortOrder Pattern Created Creator LastUpdated LastUpdatedBy);
    push @fields, qw(UniqueValues EntryHint) if RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
    ok(exists $content->{$_}, "got $_") for @fields;

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 1);
    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $select_cf_id);
    is($links->[0]{type}, 'customfield');
    like($links->[0]{_url}, qr{$rest_base_path/customfield/$select_cf_id$});

    my $values = $content->{Values};
    is_deeply($values, ['First Value', 'Second Value', 'Third Value']);
}

# BasedOn CustomField display
{
    my $res = $mech->get("$rest_base_path/customfield/$basedon_cf_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{id}, $basedon_cf_id);
    is($content->{Name}, $basedon_cf->Name);
    is($content->{Description}, '');
    is($content->{LookupType}, 'RT::Queue-RT::Ticket');
    is($content->{Type}, 'Select');
    is($content->{MaxValues}, 1);
    is($content->{Disabled}, 0);

    my @fields = qw(SortOrder Pattern Created Creator LastUpdated LastUpdatedBy);
    push @fields, qw(UniqueValues EntryHint) if RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
    ok(exists $content->{$_}, "got $_") for @fields;

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 1);
    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $basedon_cf_id);
    is($links->[0]{type}, 'customfield');
    like($links->[0]{_url}, qr{$rest_base_path/customfield/$basedon_cf_id$});

    my $values = $content->{Values};
    is_deeply($values, ['With First Value', 'With No Value']);
}

# BasedOn CustomField display with category filter
{
    my $res = $mech->get("$rest_base_path/customfield/$basedon_cf_id?category=First%20Value",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{id}, $basedon_cf_id);
    is($content->{Name}, $basedon_cf->Name);
    is($content->{Description}, '');
    is($content->{LookupType}, 'RT::Queue-RT::Ticket');
    is($content->{Type}, 'Select');
    is($content->{MaxValues}, 1);
    is($content->{Disabled}, 0);

    my @fields = qw(SortOrder Pattern Created Creator LastUpdated LastUpdatedBy);
    push @fields, qw(UniqueValues EntryHint) if RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
    ok(exists $content->{$_}, "got $_") for @fields;

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 1);
    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $basedon_cf_id);
    is($links->[0]{type}, 'customfield');
    like($links->[0]{_url}, qr{$rest_base_path/customfield/$basedon_cf_id$});

    my $values = $content->{Values};
    is_deeply($values, ['With First Value']);
}

# BasedOn CustomField display with null category filter
{
    my $res = $mech->get("$rest_base_path/customfield/$basedon_cf_id?category=",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{id}, $basedon_cf_id);
    is($content->{Name}, $basedon_cf->Name);
    is($content->{Description}, '');
    is($content->{LookupType}, 'RT::Queue-RT::Ticket');
    is($content->{Type}, 'Select');
    is($content->{MaxValues}, 1);
    is($content->{Disabled}, 0);

    my @fields = qw(SortOrder Pattern Created Creator LastUpdated LastUpdatedBy);
    push @fields, qw(UniqueValues EntryHint) if RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
    ok(exists $content->{$_}, "got $_") for @fields;

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 1);
    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $basedon_cf_id);
    is($links->[0]{type}, 'customfield');
    like($links->[0]{_url}, qr{$rest_base_path/customfield/$basedon_cf_id$});

    my $values = $content->{Values};
    is_deeply($values, ['With No Value']);
}

done_testing;


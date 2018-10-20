use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;
my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

my $alpha = RT::Test->load_or_create_queue( Name => 'Alpha' );
my $beta  = RT::Test->load_or_create_queue( Name => 'Beta' );
my $bravo = RT::Test->load_or_create_queue( Name => 'Bravo' );
$user->PrincipalObj->GrantRight( Right => 'SuperUser' );

my $alpha_id = $alpha->Id;
my $beta_id  = $beta->Id;
my $bravo_id = $bravo->Id;

# Name = General
{
    my $res = $mech->post_json("$rest_base_path/queues",
        [{ field => 'Name', value => 'General' }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 1);
    is(scalar @{$content->{items}}, 1);

    my $queue = $content->{items}->[0];
    is($queue->{type}, 'queue');
    is($queue->{id}, 1);
    like($queue->{_url}, qr{$rest_base_path/queue/1$});
}

# Name != General
{
    my $res = $mech->post_json("$rest_base_path/queues",
        [{ field => 'Name', operator => '!=', value => 'General' }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 3);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 3);
    is(scalar @{$content->{items}}, 3);

    my ($first, $second, $third) = @{ $content->{items} };
    is($first->{type}, 'queue');
    is($first->{id}, $alpha_id);
    like($first->{_url}, qr{$rest_base_path/queue/$alpha_id$});

    is($second->{type}, 'queue');
    is($second->{id}, $beta_id);
    like($second->{_url}, qr{$rest_base_path/queue/$beta_id$});

    is($third->{type}, 'queue');
    is($third->{id}, $bravo_id);
    like($third->{_url}, qr{$rest_base_path/queue/$bravo_id$});
}

# Name STARTSWITH B
{
    my $res = $mech->post_json("$rest_base_path/queues",
        [{ field => 'Name', operator => 'STARTSWITH', value => 'B' }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 2);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 2);
    is(scalar @{$content->{items}}, 2);

    my ($first, $second) = @{ $content->{items} };
    is($first->{type}, 'queue');
    is($first->{id}, $beta_id);
    like($first->{_url}, qr{$rest_base_path/queue/$beta_id$});

    is($second->{type}, 'queue');
    is($second->{id}, $bravo_id);
    like($second->{_url}, qr{$rest_base_path/queue/$bravo_id$});
}

# id > 2
{
    my $res = $mech->post_json("$rest_base_path/queues",
        [{ field => 'id', operator => '>', value => 2 }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 3);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 3);
    is(scalar @{$content->{items}}, 3);

    my ($first, $second, $third) = @{ $content->{items} };
    is($first->{type}, 'queue');
    is($first->{id}, $alpha_id);
    like($first->{_url}, qr{$rest_base_path/queue/$alpha_id$});

    is($second->{type}, 'queue');
    is($second->{id}, $beta_id);
    like($second->{_url}, qr{$rest_base_path/queue/$beta_id$});

    is($third->{type}, 'queue');
    is($third->{id}, $bravo_id);
    like($third->{_url}, qr{$rest_base_path/queue/$bravo_id$});
}

# Invalid query ({ ... })
{
    my $res = $mech->post_json("$rest_base_path/queues",
        { field => 'Name', value => 'General' },
        'Authorization' => $auth,
    );
    is($res->code, 400);

    my $content = $mech->json_response;

    TODO: {
        local $TODO = "better error reporting";
        is($content->{message}, 'Query must be an array of objects');
    }
    is($content->{message}, 'JSON object must be a ARRAY');
}

# Find disabled row
{
    $alpha->SetDisabled(1);

    my $res = $mech->post_json("$rest_base_path/queues",
        [{ field => 'id', operator => '>', value => 2 }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 2);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 2);
    is(scalar @{$content->{items}}, 2);

    my ($first, $second) = @{ $content->{items} };
    is($first->{type}, 'queue');
    is($first->{id}, $beta_id);
    like($first->{_url}, qr{$rest_base_path/queue/$beta_id$});

    is($second->{type}, 'queue');
    is($second->{id}, $bravo_id);
    like($second->{_url}, qr{$rest_base_path/queue/$bravo_id$});

    my $res_disabled = $mech->post_json("$rest_base_path/queues?find_disabled_rows=1",
        [{ field => 'id', operator => '>', value => 2 }],
        'Authorization' => $auth,
    );
    is($res_disabled->code, 200);

    my $content_disabled = $mech->json_response;
    is($content_disabled->{count}, 3);
    is($content_disabled->{page}, 1);
    is($content_disabled->{per_page}, 20);
    is($content_disabled->{total}, 3);
    is(scalar @{$content_disabled->{items}}, 3);

    my ($first_disabled, $second_disabled, $third_disabled) = @{ $content_disabled->{items} };
    is($first_disabled->{type}, 'queue');
    is($first_disabled->{id}, $alpha_id);
    like($first_disabled->{_url}, qr{$rest_base_path/queue/$alpha_id$});

    is($second_disabled->{type}, 'queue');
    is($second_disabled->{id}, $beta_id);
    like($second_disabled->{_url}, qr{$rest_base_path/queue/$beta_id$});

    is($third_disabled->{type}, 'queue');
    is($third_disabled->{id}, $bravo_id);
    like($third_disabled->{_url}, qr{$rest_base_path/queue/$bravo_id$});
}

done_testing;


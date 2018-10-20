use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;
my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

my $alpha = RT::Test->load_or_create_queue( Name => 'Alpha', Description => 'Queue for test' );
my $beta  = RT::Test->load_or_create_queue( Name => 'Beta', Description => 'Queue for test' );
my $bravo = RT::Test->load_or_create_queue( Name => 'Bravo', Description => 'Queue to test sorted search' );
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

# Sorted search
{
    my $res = $mech->post_json("$rest_base_path/queues?orderby=Description&order=DESC&orderby=id",
        [{ field => 'Description', operator => 'LIKE', value => 'test' }],
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
    is($first->{id}, $bravo_id);
    like($first->{_url}, qr{$rest_base_path/queue/$bravo_id$});

    is($second->{type}, 'queue');
    is($second->{id}, $alpha_id);
    like($second->{_url}, qr{$rest_base_path/queue/$alpha_id$});

    is($third->{type}, 'queue');
    is($third->{id}, $beta_id);
    like($third->{_url}, qr{$rest_base_path/queue/$beta_id$});
}

done_testing;


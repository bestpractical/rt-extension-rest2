use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;
my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

my $alpha = RT::Test->load_or_create_queue( Name => 'Alpha' );
my $bravo = RT::Test->load_or_create_queue( Name => 'Bravo' );
$user->PrincipalObj->GrantRight( Right => 'SuperUser' );

my $alpha_id = $alpha->Id;
my $bravo_id = $bravo->Id;

# Default per_page (20), only 1 page.
{
    my $res = $mech->post_json("$rest_base_path/queues/all",
        [],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 3);
    is($content->{page}, 1);
    is($content->{pages}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 3);
    undef($content->{prev_page});
    undef($content->{next_page});
    is(scalar @{$content->{items}}, 3);
}

# per_page = 3, only 1 page.
{
    my $res = $mech->post_json("$rest_base_path/queues/all?per_page=3",
        [],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 3);
    is($content->{page}, 1);
    is($content->{pages}, 1);
    is($content->{per_page}, 3);
    is($content->{total}, 3);
    undef($content->{prev_page});
    undef($content->{next_page});
    is(scalar @{$content->{items}}, 3);
}

# per_page = 1, 3 pages, page 1.
{
    my $url = "$rest_base_path/queues/all?per_page=1";
    my $res = $mech->post_json($url,
        [],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    # Ensure our use of $url as a regex works.
    $url =~ s/\?/\\?/;

    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 1);
    is($content->{pages}, 3);
    is($content->{per_page}, 1);
    is($content->{total}, 3);
    undef($content->{prev_page});
    like($content->{next_page}, qr[$url&page=2]);
    is(scalar @{$content->{items}}, 1);
}

# per_page = 1, 3 pages, page 2.
{
    my $url = "$rest_base_path/queues/all?per_page=1";
    my $res = $mech->post_json("$url&page=2",
        [],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    # Ensure our use of $url as a regex works.
    $url =~ s/\?/\\?/;

    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 2);
    is($content->{pages}, 3);
    is($content->{per_page}, 1);
    is($content->{total}, 3);
    like($content->{prev_page}, qr[$url&page=1]);
    like($content->{next_page}, qr[$url&page=3]);
    is(scalar @{$content->{items}}, 1);
}

# per_page = 1, 3 pages, page 3.
{
    my $url = "$rest_base_path/queues/all?per_page=1";
    my $res = $mech->post_json("$url&page=3",
        [],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    # Ensure our use of $url as a regex works.
    $url =~ s/\?/\\?/;

    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 3);
    is($content->{pages}, 3);
    is($content->{per_page}, 1);
    is($content->{total}, 3);
    like($content->{prev_page}, qr[$url&page=2]);
    undef($content->{next_page});
    is(scalar @{$content->{items}}, 1);
}

# Test sanity checking for the pagination parameters.
for my $param ( 'per_page', 'page' ) {
    for my $value ( 'abc', '-10', '30' ) {
        # No need to test the following combination.
        next if $param eq 'per_page' && $value eq '30';

        my $res = $mech->post_json("$rest_base_path/queues/all?$param=$value",
            [],
            'Authorization' => $auth,
        );
        is($res->code, 200);

        my $content = $mech->json_response;
        is($content->{count}, 3);
        is($content->{page}, 1);
        is($content->{pages}, 1);
        is($content->{per_page}, 20);
        is($content->{total}, 3);
        undef($content->{prev_page});
        undef($content->{next_page});
        is(scalar @{$content->{items}}, 3);
    }
}

done_testing;

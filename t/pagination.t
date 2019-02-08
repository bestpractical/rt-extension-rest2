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
    is($content->{prev_page}, undef);
    is($content->{next_page}, undef);
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
    is($content->{prev_page}, undef);
    is($content->{next_page}, undef);
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
    is($content->{prev_page}, undef);
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
    is($content->{next_page}, undef);
    is(scalar @{$content->{items}}, 1);
}

# Test sanity checking for the pagination parameters.
{
    my $url = "$rest_base_path/queues/all";
    for my $param ( 'per_page', 'page' ) {
	for my $value ( 'abc', '-10', '30' ) {
	    # No need to test the following combination.
	    next if $param eq 'per_page' && $value eq '30';

	    my $res = $mech->post_json("$url?$param=$value",
		[],
		'Authorization' => $auth,
	    );
	    is($res->code, 200);

	    my $content = $mech->json_response;
	    if ($param eq 'page') {
		if ($value eq '30') {
		    is($content->{count}, 0);
		    is($content->{page}, 30);
		    is(scalar @{$content->{items}}, 0);
		    like($content->{prev_page}, qr[$url\?page=1]);
		} else {
		    is($content->{count}, 3);
		    is($content->{page}, 1);
		    is(scalar @{$content->{items}}, 3);
		    is($content->{prev_page}, undef);
		}
	    }
	    is($content->{pages}, 1);
	    if ($param eq 'per_page') {
		if ($value eq '30') {
		    is($content->{per_page}, 30);
		} else {
		    is($content->{per_page}, 20);
		}
	    }
	    is($content->{total}, 3);
	    is($content->{next_page}, undef);
	}
    }
}

# Test with limit
my $alphabis = RT::Test->load_or_create_queue( Name => 'Alphabis' );
{
    my $res = $mech->post_json("$rest_base_path/queues/all?per_page=1&page=2",
        [{field => 'Name', operator => 'LIKE', value => 'Alp'}],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 2);
    is($content->{pages}, 2);
    is($content->{per_page}, 1);
    is($content->{total}, 2);
    like($content->{prev_page}, qr{/queues/all\?per_page=1&page=1$});
    is($content->{next_page}, undef);
    is(scalar @{$content->{items}}, 1);
    is($content->{items}->[0]->{id}, $alphabis->id);

    $res = $mech->post_json($content->{prev_page},
        [{field => 'Name', operator => 'LIKE', value => 'Alp'}],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 1);
    is($content->{pages}, 2);
    is($content->{per_page}, 1);
    is($content->{total}, 2);
    is($content->{prev_page}, undef);
    like($content->{next_page}, qr{/queues/all\?per_page=1&page=2$});
    is(scalar @{$content->{items}}, 1);
    is($content->{items}->[0]->{id}, $alpha->id);
}

# Pagination for ticket search
my $ticket1 = RT::Test->create_ticket(
    Queue     => $alphabis,
    Subject   => 'A first ticket',
    Requestor => ['requestor@test.com'],
);
my $ticket2 = RT::Test->create_ticket(
    Queue     => $alphabis,
    Subject   => 'A second ticket',
    Requestor => ['requestor@test.com'],
);
my $ticket3 = RT::Test->create_ticket(
    Queue     => $alphabis,
    Subject   => 'The last one',
    Requestor => ['requestor@test.com'],
);
{
    my $res = $mech->get("$rest_base_path/tickets/?query=Subject+LIKE+'ticket'&per_page=1&page=2",
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 2);
    is($content->{pages}, 2);
    is($content->{per_page}, 1);
    is($content->{total}, 2);
    like($content->{prev_page}, qr{/tickets/\?query=Subject\+LIKE\+'ticket'&per_page=1&page=1$});
    is($content->{next_page}, undef);
    is(scalar @{$content->{items}}, 1);
    is($content->{items}->[0]->{id}, $ticket2->id);

    $res = $mech->get($content->{prev_page},
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 1);
    is($content->{pages}, 2);
    is($content->{per_page}, 1);
    is($content->{total}, 2);
    is($content->{prev_page}, undef);
    like($content->{next_page}, qr{/tickets/\?query=Subject\+LIKE\+'ticket'&per_page=1&page=2$});
    is(scalar @{$content->{items}}, 1);
    is($content->{items}->[0]->{id}, $ticket1->id);
}

done_testing;

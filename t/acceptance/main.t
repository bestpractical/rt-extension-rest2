use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;
ok(my $res = $mech->get('/'));
is($res->code, 401, 'Unauthorized');
is($res->content, 'Authorization required');
like($res->header('www-authenticate'), qr/example\.com\s+API/);

done_testing;

use strict;
use warnings;
use 5.010;

package RTx::REST;

our $VERSION = '0.01';

use UNIVERSAL::require;
use Plack::Builder;
use Web::Machine;

=encoding utf-8

=head1 NAME

RTx-REST - Adds a modern REST API to RT under /REST/2.0/

=head1 USAGE

=head2 Summary

Currently provided endpoints under C</REST/2.0/> are:

    GET /ticket/:id
    PUT /ticket/:id <JSON body>
    DELETE /ticket/:id
        Sets ticket status to "deleted".

    GET /queue/:id
    PUT /queue/:id <JSON body>
    DELETE /queue/:id
        Disables the queue.

    GET /user/:id
    PUT /user/:id <JSON body>
    DELETE /user/:id
        Disables the user.

For queues and users, C<:id> may be the numeric id or the unique name.

When a GET request is made, each endpoint returns a JSON representation of the
specified resource, or a 404 if not found.

When a PUT request is made, the request body should be a modified copy (or
partial copy) of the JSON representation of the specified resource, and the
record will be updated.

A DELETE request to a resource will delete or disable the underlying record.

=head2 Creating

    POST /ticket
    POST /queue
    POST /user

A POST request to a resource endpoint, without a specific id/name, will create
a new resource of that type.  The request should have a JSON payload similar to
the ones returned for existing resources.

On success, the return status is 201 Created and a Location header points to
the new resource uri.  On failure, the status code indicates the nature of the
issue, and a descriptive message is in the response body.

=head2 Searching

=head3 Tickets

    GET /tickets?query=<TicketSQL>
    GET /tickets?simple=1;query=<simple search query>
    POST /tickets
        With the 'query' and optional 'simple' parameters

The C<query> parameter expects TicketSQL by default unless a true value is sent
for the C<simple> parameter.

Results are returned in
L<the format described below|/"Example of plural resources (collections)">.

=head3 Queues and users

    POST /queues
    POST /users

These resources accept a basic JSON structure as the search conditions which
specifies one or more fields to limit on (using specified operators and
values).  An example:

    curl -si -u user:pass http://rt.example.com/REST/2.0/queues -XPOST --data-binary '
        [
            { "field":    "Name",
              "operator": "LIKE",
              "value":    "Engineering" },

            { "field":    "Lifecycle",
              "value":    "helpdesk" }
        ]
    '

The JSON payload must be an array of hashes with the keys C<field> and C<value>
and optionally C<operator>.

Results are returned in
L<the format described below|/"Example of plural resources (collections)">.

=head2 Example of plural resources (collections)

Resources which represent a collection of other resources use the following
standard JSON format:

    {
       "count" : 20,
       "page" : 1,
       "per_page" : 20,
       "total" : 3810,
       "items" : [
          { … },
          { … },
          …
       ]
    }

Each item is nearly the same representation used when an individual resource
is requested.

=head2 Paging

All plural resources (such as C</tickets>) require pagination, controlled by
the query parameters C<page> and C<per_page>.  The default page size is 20
items, but it may be increased up to 100 (or decreased if desired).  Page
numbers start at 1.

=head2 Authentication

Currently authentication is limited to internal RT usernames and passwords,
provided via HTTP Basic auth.  Most HTTP libraries already have a way of
providing basic auth credentials when making requests.  Using curl, for
example:

    curl -u username:password …

This sort of authentication should B<always> be done over HTTPS/SSL for
security.  You should only serve up the C</REST/2.0/> endpoint over SSL.

=head2 Conditional requests (If-Modified-Since)

You can take advantage of the C<Last-Modified> headers returned by most single
resource endpoints.  Add a C<If-Modified-Since> header to your requests for
the same resource, using the most recent C<Last-Modified> value seen, and the
API may respond with a 304 Not Modified.  You can also use HEAD requests to
check for updates without receiving the actual content when there is a newer
version.

=head2 Status codes

The REST API uses the full range of HTTP status codes, and your client should
handle them appropriately.

=cut

# XXX TODO: API doc

sub resources {
    return qw(
        Queue
        Queues
        Ticket
        Tickets
        User
        Users
    );
}

sub resource {
    Web::Machine->new(
        resource => "RTx::REST::Resource::$_[0]",
    )->to_app;
}

sub app {
    my $class = shift;
    return sub {
        my ($env) = @_;
        $env->{'psgix.logger'} = sub {
            my $what = shift;
            RT->Logger->log(%$what);
        };
        # XXX TODO: logging of SQL queries in RT's framework for doing so
        # XXX TODO: Need a dispatcher?  Or do it inside resources?  Web::Simple?
        RT::ConnectToDatabase();
        my $dispatch = builder {
            # XXX TODO: better auth integration
            enable "Auth::Basic",
                realm         => RT->Config->Get("rtname") . " API",
                authenticator => sub {
                    my ($user, $pass, $env) = @_;
                    my $cu = RT::CurrentUser->new;
                    $cu->Load($user);

                    if ($cu->id and $cu->IsPassword($pass)) {
                        $env->{"rt.current_user"} = $cu;
                        return 1;
                    } else {
                        RT->Logger->error("FAILED LOGIN for $user from $env->{REMOTE_ADDR}");
                        return 0;
                    }
                };
            for ($class->resources) {
                (my $path = lc $_) =~ s{::}{/}g;
                mount "/$path" => resource($_);
            }
            mount "/"       => sub { [ 404, ['Content-type' => 'text/plain'], ['Unknown resource'] ] };
        };
        $dispatch->(@_);
    }
}

# Called by RT::Interface::Web::Handler->PSGIApp
sub PSGIWrap {
    my ($class, $app) = @_;
    builder {
        mount "/REST/2.0"   => $class->app;
        mount "/"           => $app;
    };
}

=head1 INSTALLATION 

=over

=item C<perl Makefile.PL>

=item C<make>

=item C<make install>

May need root permissions

=item Edit your F</opt/rt4/etc/RT_SiteConfig.pm>

Add this line:

    Set(@Plugins, qw(RTx::REST));

or add C<RTx::REST> to your existing C<@Plugins> line.

=item Clear your mason cache

    rm -rf /opt/rt4/var/mason_data/obj

=item Restart your webserver

=back

=head1 AUTHOR

Thomas Sibley <trs@bestpractical.com>

=head1 BUGS

All bugs should be reported via email to
L<bug-RTx-REST@rt.cpan.org|mailto:bug-RTx-REST@rt.cpan.org>
or via the web at
L<rt.cpan.org|http://rt.cpan.org/Public/Dist/Display.html?Name=RTx-REST>.

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2013 by Best Practical Solutions

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut

1;

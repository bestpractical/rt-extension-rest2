use strict;
use warnings;
use 5.010001;

package RT::Extension::REST2;

our $VERSION = '0.10';
our $REST_PATH = '/REST/2.0';

use UNIVERSAL::require;
use Plack::Builder;
use RT::Extension::REST2::Dispatcher;

=encoding utf-8

=head1 NAME

RT-Extension-REST2 - Adds a modern REST API to RT under /REST/2.0/

=head1 INSTALLATION

=over

=item C<perl Makefile.PL>

=item C<make>

=item C<make install>

May need root permissions

=item Edit your F</opt/rt4/etc/RT_SiteConfig.pm>

Add this line:

    Plugin('RT::Extension::REST2');

=item Clear your mason cache

    rm -rf /opt/rt4/var/mason_data/obj

=item Restart your webserver

=back

=head1 CONFIGURATION

=over

=item C<$RESTPath>

The relative path from C<$WebPath> where you want to have the REST API being
served.

C<$RESTPath> requires a leading / but no trailing /, or it can be blank.

Defaults to C</REST/2.0>. Thus, if you have C<$WebPath> set to C</rt> then the
base REST API URI will be like C<https://example.com/rt/REST/2.0>.

=back

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

    curl -si -u user:pass https://rt.example.com/REST/2.0/queues -XPOST --data-binary '
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

Authentication is limited to internal RT usernames and passwords, provided via
HTTP Basic auth. Most HTTP libraries already have a way of providing basic
auth credentials when making requests.  Using curl, for example:

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

sub to_psgi_app { shift->to_app(@_) }

sub to_app {
    my $class = shift;

    RT::ConnectToDatabase();

    my $rest_path = $class->rest_path;

    return builder {
        enable '+RT::Extension::REST2::Middleware::Log';
        enable '+RT::Extension::REST2::Middleware::Auth';
        enable 'RequestHeaders',
            set => [
                'X-Forwarded-Script-Name' => '/',
                'X-Traversal-Path' => $rest_path,
            ];
        enable 'ReverseProxyPath';
        RT::Extension::REST2::Dispatcher->to_psgi_app;
    };
}

sub base_path {
    RT->Config->Get('WebPath') . $REST_PATH
}

sub base_uri {
    RT->Config->Get('WebBaseURL') . shift->base_path
}

# Called by RT::Interface::Web::Handler->PSGIApp
sub PSGIWrap {
    my ($class, $app) = @_;
    return builder {
        mount $REST_PATH => $class->to_app;
        mount '/' => $app;
    };
}

=head1 AUTHOR

Best Practical Solutions, LLC <modules@bestpractical.com>

=head1 BUGS

All bugs should be reported via email to
L<bug-RT-Extension-REST2@rt.cpan.org|mailto:bug-RT-Extension-REST2@rt.cpan.org>
or via the web at
L<rt.cpan.org|http://rt.cpan.org/Public/Dist/Display.html?Name=RT-Extension-REST2>.

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2015 by Best Practical Solutions, LLC.

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut

1;

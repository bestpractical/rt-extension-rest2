use strict;
use warnings;
use 5.010001;

package RT::Extension::REST2;

our $VERSION = '1.04';
our $REST_PATH = '/REST/2.0';

use Plack::Builder;
use RT::Extension::REST2::Dispatcher;

=encoding utf-8

=head1 NAME

RT::Extension::REST2 - Adds a modern REST API to RT under /REST/2.0/

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

=head1 USAGE

=head2 Tutorial

To make it easier to authenticate to REST2, we recommend installing
L<RT::Authen::Token>. Visit "Logged in as ___" -> Settings -> Auth
Tokens. Create an Auth Token, give it any description (such as "REST2
with curl"). Make note of the authentication token it provides to you.

For other authentication options see the section
L<Authentication Methods> below.

=head3 Authentication

Run the following in a terminal, filling in XX_TOKEN_XX from the auth
token above and XX_RT_URL_XX with the URL for your RT instance.

    curl -H 'Authorization: token XX_TOKEN_XX' 'XX_RT_URL_XX/REST/2.0/queues/all'

This does an authenticated request (using the C<Authorization> HTTP
header with type C<token>) for all of the queues you can see. You should
see a response, typical of search results, like this:

    {
       "total" : 1,
       "count" : 1,
       "page" : 1,
       "per_page" : 20,
       "items" : [
          {
             "type" : "queue",
             "id" : "1",
             "_url" : "XX_RT_URL_XX/REST/2.0/queue/1"
          }
       ]
    }

This format is JSON, which is a format for which many programming languages
provide libraries for parsing and generating.

(If you instead see a response like C<{"message":"Unauthorized"}> that
indicates RT couldn't process your authentication token successfully;
make sure the word "token" appears between "Authorization:" and the auth
token that RT provided to you)

=head3 Following Links

You can request one of the provided C<_url>s to get more information
about that queue.

    curl -H 'Authorization: token XX_TOKEN_XX' 'XX_QUEUE_URL_XX'

This will give a lot of information, like so:

    {
       "id" : 1,
       "Name" : "General",
       "Description" : "The default queue",
       "Lifecycle" : "default",
       ...
       "CustomFields" : {},
       "_hyperlinks" : [
          {
             "id" : "1",
             "ref" : "self",
             "type" : "queue",
             "_url" : "XX_RT_URL_XX/REST/2.0/queue/1"
          },
          {
             "ref" : "history",
             "_url" : "XX_RT_URL_XX/REST/2.0/queue/1/history"
          },
          {
             "ref" : "create",
             "type" : "ticket",
             "_url" : "XX_RT_URL_XX/REST/2.0/ticket?Queue=1"
          }
       ],
    }

Of particular note is the C<_hyperlinks> key, which gives you a list of
related resources to examine (following the
L<https://en.wikipedia.org/wiki/HATEOAS> principle). For example an
entry with a C<ref> of C<history> lets you examine the transaction log
for a record. You can implement your REST API client knowing that any
other hypermedia link with a C<ref> of C<history> has the same meaning,
regardless of whether it's the history of a queue, ticket, asset, etc.

Another C<ref> you'll see in C<_hyperlinks> is C<create>, with a C<type>
of C<ticket>. This of course gives you the URL to create tickets
I<in this queue>. Importantly, if your user does I<not> have the
C<CreateTicket> permission in this queue, then REST2 would simply not
include this hyperlink in its response to your request. This allows you
to dynamically adapt your client's behavior to its presence or absence,
just like the web version of RT does.

=head3 Creating Tickets

Let's use the C<_url> from the C<create> hyperlink with type C<ticket>.

To create a ticket is a bit more involved, since it requires providing a
different HTTP verb (C<POST> instead of C<GET>), a C<Content-Type>
header (to tell REST2 that your content is JSON instead of, say, XML),
and the fields for your new ticket such as Subject. Here is the curl
invocation, wrapped to multiple lines for readability.

    curl -X POST
         -H "Content-Type: application/json"
         -d '{ "Subject": "hello world" }'
         -H 'Authorization: token XX_TOKEN_XX'
            'XX_TICKET_CREATE_URL_XX'

If successful, that will provide output like so:

    {
        "_url" : "XX_RT_URL_XX/REST/2.0/ticket/20",
        "type" : "ticket",
        "id"   : "20"
    }

(REST2 also produces the status code of C<201 Created> with a C<Location>
header of the new ticket, which you may choose to use instead of the
JSON response)

We can fetch that C<_url> to continue working with this newly-created
ticket. Request the ticket like so (make sure to include the C<-i> flag
to see response's HTTP headers).

    curl -i -H 'Authorization: token XX_TOKEN_XX' 'XX_TICKET_URL_XX'

You'll first see that there are many hyperlinks for tickets, including
one for each Lifecycle action you can perform, history, comment,
correspond, etc. Again these adapt to whether you have the appropriate
permissions to do these actions.

Additionally you'll see an C<ETag> header for this record, which can be
used for conflict avoidance
(L<https://en.wikipedia.org/wiki/HTTP_ETag>). We'll first try updating this
ticket with an I<invalid> C<ETag> to see what happens.

=head3 Updating Tickets

For updating tickets we use the C<PUT> verb, but otherwise it looks much
like a ticket creation.

    curl -X PUT
         -H "Content-Type: application/json"
         -H "If-Match: invalid-etag"
         -d '{ "Subject": "trial update" }'
         -H 'Authorization: token XX_TOKEN_XX'
            'XX_TICKET_URL_XX'

You'll get an error response like C<{"message":"Precondition Failed"}>
and a status code of 412. If you examine the ticket, you'll also see
that its Subject was not changed. This is because the C<If-Match> header
advises the server to make changes I<if and only if> the ticket's
C<ETag> matches what you provide. Since it differed, the server refused
the request and made no changes.

Now, try the same request by replacing the value "invalid-etag" in the
C<If-Match> request header with the real C<ETag> you'd received when you
requested the ticket previously. You'll then get a JSON response like:

    ["Ticket 1: Subject changed from 'hello world' to 'trial update'"]

which is a list of messages meant for displaying to an end-user.

If you C<GET> the ticket again, you'll observe that the C<ETag>
header now has a different value, indicating that the ticket itself has
changed. This means if you were to retry the C<PUT> update with the
previous (at the time, expected) C<ETag> you would instead be rejected
by the server with Precondition Failed.

You can use C<ETag> and C<If-Match> headers to avoid race conditions
such as two people updating a ticket at the same time. Depending on the
sophistication of your client, you may be able to automatically retry
the change by incorporating the changes made on the server (for example
adding time worked can be automatically be recalculated).

You may of course choose to ignore the C<ETag> header and not provide
C<If-Match> in your requests; RT doesn't require its use.

=head3 Summary

RT's REST2 API provides the tools you need to build robust and dynamic
integrations. Tools like C<ETag>/C<If-Match> allow you to avoid
conflicts such as two people taking a ticket at the same time. Using
JSON for all data interchange avoids problems caused by parsing text.
Hypermedia links inform your client application of what the user has the
ability to do.

Careful readers will see that, other than our initial entry into the
system, we did not I<generate> any URLs. We only I<followed> links, just
like you do when browsing a website on your computer. We've better
decoupled the client's implementation from the server's REST API.
Additionally, this system lets you be informed of new capabilities in
the form of additional hyperlinks.

Using these tools and principles, REST2 will help you build rich,
robust, and powerful integrations with the other applications and
services that your team uses.

=head2 Endpoints

Currently provided endpoints under C</REST/2.0/> are described below.
Wherever possible please consider using C<_hyperlinks> hypermedia
controls available in response bodies rather than hardcoding URLs.

For simplicity, the examples below omit the extra options to
curl for SSL like --cacert.

=head3 Tickets

    GET /tickets?query=<TicketSQL>
        search for tickets using TicketSQL

    GET /tickets?simple=1;query=<simple search query>
        search for tickets using simple search syntax

    POST /tickets
        search for tickets with the 'query' and optional 'simple' parameters

    POST /ticket
        create a ticket; provide JSON content

    GET /ticket/:id
        retrieve a ticket

    PUT /ticket/:id
        update a ticket's metadata; provide JSON content

    DELETE /ticket/:id
        set status to deleted

    POST /ticket/:id/correspond
    POST /ticket/:id/comment
        add a reply or comment to the ticket

    GET /ticket/:id/history
        retrieve list of transactions for ticket

    POST /tickets/bulk
        create multiple tickets; provide JSON content(array of hashes)

    PUT /tickets/bulk
        update multiple tickets' metadata; provide JSON content(array of hashes)

=head3 Ticket Examples

Below are some examples using the endpoints above.

    # Create a ticket, setting some custom fields
    curl -X POST -H "Content-Type: application/json" -u 'root:password'
        -d '{ "Queue": "General", "Subject": "Create ticket test",
            "From": "user1@example.com", "To": "rt@example.com",
            "Content": "Testing a create",
            "CustomFields": {"Severity": "Low"}}'
        'https://myrt.com/REST/2.0/ticket'

    # Update a ticket, with a custom field update
    curl -X PUT -H "Content-Type: application/json" -u 'root:password'
        -d '{ "Subject": "Update test", "CustomFields": {"Severity": "High"}}'
        'https://myrt.com/REST/2.0/ticket/6'

    # Correspond a ticket
    curl -X POST -H "Content-Type: application/json" -u 'root:password'
        -d '{ "Content": "Testing a correspondence", "ContentType": "text/plain" }'
        'https://myrt.com/REST/2.0/ticket/6/correspond'

    # Comment a ticket
    curl -X POST -H "Content-Type: text/plain" -u 'root:password'
        -d 'Testing a comment'
        'https://myrt.com/REST/2.0/ticket/6/comment'

    # Create an Asset
    curl -X POST -H "Content-Type: application/json" -u 'root:password'
        -d '{"Name" : "Asset From Rest", "Catalog" : "General assets", "Content" : "Some content"}'
        'https://myrt.com/REST/2.0/asset'

    # Search Assets
    curl -X POST -H "Content-Type: application/json" -u 'root:password'
    -d '[{ "field" : "id", "operator" : ">=", "value" : 0 }]'
    'https://myrt.com/REST/2.0/asset'

=head3 Transactions

    GET /transactions?query=<JSON>
    POST /transactions
        search for transactions using L</JSON searches> syntax

    GET /ticket/:id/history
    GET /queue/:id/history
    GET /queue/:name/history
    GET /asset/:id/history
    GET /user/:id/history
    GET /user/:name/history
    GET /group/:id/history
        get transactions for record

    GET /transaction/:id
        retrieve a transaction

=head3 Attachments and Messages

    GET /attachments?query=<JSON>
    POST /attachments
        search for attachments using L</JSON searches> syntax

    GET /transaction/:id/attachments
        get attachments for transaction

    GET /attachment/:id
        retrieve an attachment

=head3 Queues

    GET /queues/all
        retrieve list of all queues you can see

    GET /queues?query=<JSON>
    POST /queues
        search for queues using L</JSON searches> syntax

    POST /queue
        create a queue; provide JSON content

    GET /queue/:id
    GET /queue/:name
        retrieve a queue by numeric id or name

    PUT /queue/:id
    PUT /queue/:name
        update a queue's metadata; provide JSON content

    DELETE /queue/:id
    DELETE /queue/:name
        disable queue

    GET /queue/:id/history
    GET /queue/:name/history
        retrieve list of transactions for queue

=head3 Assets

    GET /assets?query=<JSON>
    POST /assets
        search for assets using L</JSON searches> syntax

    POST /asset
        create an asset; provide JSON content

    GET /asset/:id
        retrieve an asset

    PUT /asset/:id
        update an asset's metadata; provide JSON content

    DELETE /asset/:id
        set status to deleted

    GET /asset/:id/history
        retrieve list of transactions for asset

=head3 Catalogs

    GET /catalogs/all
        retrieve list of all catalogs you can see

    GET /catalogs?query=<JSON>
    POST /catalogs
        search for catalogs using L</JSON searches> syntax

    POST /catalog
        create a catalog; provide JSON content

    GET /catalog/:id
    GET /catalog/:name
        retrieve a catalog by numeric id or name

    PUT /catalog/:id
    PUT /catalog/:name
        update a catalog's metadata; provide JSON content

    DELETE /catalog/:id
    DELETE /catalog/:name
        disable catalog

=head3 Users

    GET /users?query=<JSON>
    POST /users
        search for users using L</JSON searches> syntax

    POST /user
        create a user; provide JSON content

    GET /user/:id
    GET /user/:name
        retrieve a user by numeric id or username

    PUT /user/:id
    PUT /user/:name
        update a user's metadata; provide JSON content

    DELETE /user/:id
    DELETE /user/:name
        disable user

    GET /user/:id/history
    GET /user/:name/history
        retrieve list of transactions for user

=head3 Groups

    GET /groups?query=<JSON>
    POST /groups
        search for groups using L</JSON searches> syntax

    GET /group/:id
        retrieve a group (including its members)

    GET /group/:id/history
        retrieve list of transactions for group

=head3 Custom Fields

    GET /customfields?query=<JSON>
    POST /customfields
        search for custom fields using L</JSON searches> syntax

    GET /customfield/:id
        retrieve a custom field

=head3 Custom Roles

    GET /customroles?query=<JSON>
    POST /customroles
        search for custom roles using L</JSON searches> syntax

    GET /customrole/:id
        retrieve a custom role

=head3 Miscellaneous

    GET /
        produces this documentation

    GET /rt
        produces system information

=head2 JSON searches

Some resources accept a basic JSON structure as the search conditions which
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

=head2 Authentication Methods

Authentication should B<always> be done over HTTPS/SSL for
security. You should only serve up the C</REST/2.0/> endpoint over SSL.

=head3 Basic Auth

Authentication may use internal RT usernames and passwords, provided via
HTTP Basic auth. Most HTTP libraries already have a way of providing basic
auth credentials when making requests.  Using curl, for example:

    curl -u 'username:password' /path/to/REST/2.0

=head3 Token Auth

You may use the L<RT::Authen::Token> extension to authenticate to the
REST 2 API. Once you've acquired an authentication token in the web
interface, specify the C<Authorization> header with a value of "token"
like so:

    curl -H 'Authorization: token …' /path/to/REST/2.0

If the library or application you're using does not support specifying
additional HTTP headers, you may also pass the authentication token as a
query parameter like so:

    curl /path/to/REST/2.0?token=…

=head3 Cookie Auth

Finally, you may reuse an existing cookie from an ordinary web session
to authenticate against REST2. This is primarily intended for
interacting with REST2 via JavaScript in the browser. Other REST
consumers are advised to use the alternatives above.

=head2 Conditional requests (If-Modified-Since, If-Match)

You can take advantage of the C<Last-Modified> headers returned by most
single resource endpoints.  Add a C<If-Modified-Since> header to your
requests for the same resource, using the most recent C<Last-Modified>
value seen, and the API may respond with a 304 Not Modified.  You can
also use HEAD requests to check for updates without receiving the actual
content when there is a newer version. You may also add an
C<If-Unmodified-Since> header to your updates to tell the server to
refuse updates if the record had been changed since you last retrieved
it.

C<ETag>, C<If-Match>, and C<If-None-Match> work similarly to
C<Last-Modified>, C<If-Modified-Since>, and C<If-Unmodified-Since>,
except that they don't use a timestamp, which has its own set of
tradeoffs. C<ETag> is an opaque value, so it has no meaning to consumers
(unlike timestamps). However, timestamps have the disadvantage of having
a resolution of seconds, so two updates happening in the same second
would produce incorrect results, whereas C<ETag> does not suffer from
that problem.

=head2 Status codes

The REST API uses the full range of HTTP status codes, and your client should
handle them appropriately.

=cut

# XXX TODO: API doc

sub to_psgi_app {
    my $self = shift;
    my $res = $self->to_app(@_);

    return Plack::Util::response_cb($res, sub {
        my $res = shift;
        $self->CleanupRequest;
    });
}

sub to_app {
    my $class = shift;

    return builder {
        enable '+RT::Extension::REST2::Middleware::ErrorAsJSON';
        enable '+RT::Extension::REST2::Middleware::Log';
        enable '+RT::Extension::REST2::Middleware::Auth';
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

sub CleanupRequest {

    if ( $RT::Handle && $RT::Handle->TransactionDepth ) {
        $RT::Handle->ForceRollback;
        $RT::Logger->crit(
            "Transaction not committed. Usually indicates a software fault."
            . "Data loss may have occurred" );
    }

    # Clean out the ACL cache. the performance impact should be marginal.
    # Consistency is imprived, too.
    RT::Principal->InvalidateACLCache();
    DBIx::SearchBuilder::Record::Cachable->FlushCache
      if ( RT->Config->Get('WebFlushDbCacheEveryRequest')
        and UNIVERSAL::can(
            'DBIx::SearchBuilder::Record::Cachable' => 'FlushCache' ) );
}

=head1 AUTHOR

Best Practical Solutions, LLC <modules@bestpractical.com>

=head1 BUGS

All bugs should be reported via email to
L<bug-RT-Extension-REST2@rt.cpan.org|mailto:bug-RT-Extension-REST2@rt.cpan.org>
or via the web at
L<rt.cpan.org|http://rt.cpan.org/Public/Dist/Display.html?Name=RT-Extension-REST2>.

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2015-2017 by Best Practical Solutions, LLC.

This is free software, licensed under:

The GNU General Public License, Version 2, June 1991

=cut

1;

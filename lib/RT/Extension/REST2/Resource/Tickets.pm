package RT::Extension::REST2::Resource::Tickets;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::ProcessPOSTasGET';

use Encode qw( decode_utf8 );
use RT::Extension::REST2::Util qw( error_as_json );
use RT::Search::Simple;

has 'query' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
    lazy_build  => 1,
);

sub _build_query {
    my $self  = shift;
    my $query = decode_utf8($self->request->param('query') || "");

    if ($self->request->param('simple') and $query) {
        # XXX TODO: Note that "normal" ModifyQuery callback isn't invoked
        # XXX TODO: Special-casing of "#NNN" isn't used
        my $search = RT::Search::Simple->new(
            Argument    => $query,
            TicketsObj  => $self->collection,
        );
        $query = $search->QueryToSQL;
    }
    return $query;
}

sub allowed_methods {
    [ 'GET', 'HEAD', 'POST' ]
}

sub limit_collection {
    my $self = shift;
    my $collection = $self->collection;
    my ($ok, $msg) = $collection->FromSQL( $self->query );
    if ($ok) {
        unless ($collection->Count) {
            ($ok, $msg) = (0, 'No tickets found');
        }
    }
    return error_as_json(
        $self->response, $ok ? 1 : 0, $msg
    );
}

__PACKAGE__->meta->make_immutable;

1;

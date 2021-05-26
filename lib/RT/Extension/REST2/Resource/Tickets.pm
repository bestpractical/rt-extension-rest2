package RT::Extension::REST2::Resource::Tickets;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::ProcessPOSTasGET',
    'RT::Extension::REST2::Resource::Collection::Search';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/tickets/?$},
        block => sub { { collection_class => 'RT::Tickets' } },
    )
}

use Encode qw( decode_utf8 );
use RT::Extension::REST2::Util qw( error_as_json expand_uid );
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

override 'limit_collection' => sub {
    my $self = shift;
    my ($ok, $msg) = $self->collection->FromSQL( $self->query );
    return error_as_json( $self->response, 0, $msg ) unless $ok;
    super();
    return 1;
};

sub expand_field {
    my $self         = shift;
    my $item         = shift;
    my $field        = shift;
    my $param_prefix = shift;
    if ( $field =~ /^(Requestor|AdminCc|Cc)/ ) {
        my $role    = $1;
        my $members = [];
        if ( my $group = $item->RoleGroup($role) ) {
            my $gms = $group->MembersObj;
            while ( my $gm = $gms->Next ) {
                push @$members, $self->_expand_object( $gm->MemberObj->Object, $field, $param_prefix );
            }
        }
        return $members;
    }
    return $self->SUPER::expand_field( $item, $field, $param_prefix );
}

__PACKAGE__->meta->make_immutable;

1;

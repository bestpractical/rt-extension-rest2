package RT::Extension::REST2::Resource::Searches;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::ProcessPOSTasGET',
    'RT::Extension::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/searches/?$},
        block => sub { { collection_class => 'RT::Attributes' } },
    )
}

use Encode qw( decode_utf8 );
use RT::Extension::REST2::Util qw( error_as_json );
use RT::Search::Simple;

sub allowed_methods {
    [ 'GET', 'HEAD', 'POST' ]
}

sub limit_collection {
    my $self = shift;
    my @objects = RT::SavedSearch->new($self->current_user)->ObjectsForLoading;
    if ( $self->current_user->HasRight( Object => $RT::System, Right => 'ShowSavedSearches' ) ) {
        push @objects, RT::System->new( $self->current_user );
    }

    my $query       = $self->query;
    my @fields      = $self->searchable_fields;
    my %searchable  = map {; $_ => 1 } @fields;

    my @ids;
    my @attrs;
    for my $object (@objects) {
        my $attrs = $object->Attributes;
        $attrs->Limit( FIELD => 'Name', VALUE => 'SavedSearch' );
        push @attrs, $attrs;
    }

    # Default system searches
    my $attrs = RT::System->new( $self->current_user )->Attributes;
    $attrs->Limit( FIELD => 'Name', VALUE => 'Search -', OPERATOR => 'STARTSWITH' );
    push @attrs, $attrs;

    for my $attrs (@attrs) {
        for my $limit (@$query) {
            next
                unless $limit->{field}
                and $searchable{ $limit->{field} }
                and defined $limit->{value};

            $attrs->Limit(
                FIELD => $limit->{field},
                VALUE => $limit->{value},
                (   $limit->{operator} ? ( OPERATOR => $limit->{operator} )
                    : ()
                ),
                CASESENSITIVE => ( $limit->{case_sensitive} || 0 ),
                (   $limit->{entry_aggregator} ? ( ENTRYAGGREGATOR => $limit->{entry_aggregator} )
                    : ()
                ),
            );
        }
        push @ids, map { $_->Id } @{ $attrs->ItemsArrayRef };
    }

    while ( @ids > 1000 ) {
        my @batch = splice( @ids, 0, 1000 );
        $self->Limit( FIELD => 'id', VALUE => \@ids, OPERATOR => 'IN' );
    }
    $self->collection->Limit( FIELD => 'id', VALUE => \@ids, OPERATOR => 'IN' );

    return 1;
}

sub serialize_record {
    my $self   = shift;
    my $record = shift;
    my $result = $self->SUPER::serialize_record($record);
    $result->{type} = 'search';
    $result->{_url} =~ s!/attribute/!/search/!;
    return $result;
}

__PACKAGE__->meta->make_immutable;

1;

package RT::Extension::REST2::Resource::Search;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Record';
with 'RT::Extension::REST2::Resource::Record::Readable',
    'RT::Extension::REST2::Resource::Record::Hypermedia' =>
    { -alias => { _self_link => '_default_self_link', hypermedia_links => '_default_hypermedia_links' } };

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/search/?$},
        block => sub { { record_class => 'RT::Attribute' } },
        ),
        Path::Dispatcher::Rule::Regex->new(
            regex => qr{^/search/(.+)/?$},
            block => sub {
                my ($match, $req) = @_;
                my $desc = $match->pos(1);
                my $record = _load_search($req, $desc);

                return { record_class => 'RT::Attribute', record_id => $record ? $record->Id : 0 };
            },
        );
}

sub _self_link {
    my $self   = shift;
    my $result = $self->_default_self_link(@_);

    $result->{type} = 'search';
    $result->{_url} =~ s!/attribute/!/search/!;
    return $result;
}

sub hypermedia_links {
    my $self = shift;
    my $links = $self->_default_hypermedia_links;
    my $record = $self->record;
    if ( my $content = $record->Content ) {
        if ( ( $content->{SearchType} || 'Ticket' ) eq 'Ticket' ) {
            my $id = $record->Id;
            push @$links,
                {   _url => RT::Extension::REST2->base_uri . "/tickets?search=$id",
                    type => 'results',
                    ref  => 'tickets',
                };
        }
    }
    return $links;
}

sub base_uri { join '/', RT::Extension::REST2->base_uri, 'search' }

sub resource_exists {
    my $self   = shift;
    my $record = $self->record;
    return $record->Id && $record->Name =~ /^(?:SavedSearch$|Search -)/;
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->resource_exists;
    my $search = RT::SavedSearch->new( $self->current_user );
    return $search->LoadById( $self->record->Id ) ? 0 : 1;
}

sub _load_search {
    my $req = shift;
    my $id  = shift;

    if ( $id =~ /\D/ ) {

        my $attrs = RT::Attributes->new( $req->env->{"rt.current_user"} );

        $attrs->Limit( FIELD => 'Name',        VALUE => 'SavedSearch' );
        $attrs->Limit( FIELD => 'Name',        VALUE => 'Search -', OPERATOR => 'STARTSWITH' );
        $attrs->Limit( FIELD => 'Description', VALUE => $id );

        my @searches;
        while ( my $attr = $attrs->Next ) {
            my $search = RT::SavedSearch->new( $req->env->{"rt.current_user"} );
            if ( $search->LoadById( $attr->Id ) ) {
                push @searches, $search;
            }
        }

        my $record_id;
        if (@searches) {
            if ( @searches > 1 ) {
                RT->Logger->warning("Found multiple searches with description $id");
            }
            return $searches[0];
        }
    }
    else {
        my $search = RT::SavedSearch->new( $req->env->{"rt.current_user"} );
        if ( $search->LoadById($id) ) {
            return $search;
        }
    }
    return;
}

__PACKAGE__->meta->make_immutable;

1;

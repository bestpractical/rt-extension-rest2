package RT::Extension::REST2::Resource::Collection;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource';

use Scalar::Util qw( blessed );
use Web::Machine::FSM::States qw( is_status_code );
use Module::Runtime qw( require_module );
use RT::Extension::REST2::Util qw( serialize_record expand_uid format_datetime );

has 'collection_class' => (
    is  => 'ro',
    isa => 'ClassName',
);

has 'collection' => (
    is          => 'ro',
    isa         => 'RT::SearchBuilder',
    required    => 1,
    lazy_build  => 1,
);

sub _build_collection {
    my $self = shift;
    my $collection = $self->collection_class->new( $self->current_user );
    return $collection;
}

sub setup_paging {
    my $self = shift;
    my $per_page = $self->request->param('per_page') || 20;
       $per_page = 20  if $per_page <= 0;
       $per_page = 100 if $per_page > 100;
    $self->collection->RowsPerPage($per_page);

    my $page = $self->request->param('page') || 1;
       $page = 1 if $page < 0;
    $self->collection->GotoPage($page - 1);
}

sub limit_collection { 1 }

sub search {
    my $self = shift;
    $self->setup_paging;
    return $self->limit_collection;
}

sub serialize {
    my $self = shift;
    my $collection = $self->collection;
    my @results;
    my @fields = defined $self->request->param('fields') ? split(/,/, $self->request->param('fields')) : ();

    while (my $item = $collection->Next) {
        my $result = expand_uid( $item->UID );

        # Allow selection of desired fields
        if ($result) {
            for my $field (@fields) {
                my $field_result = $self->expand_field($item, $field);
                $result->{$field} = $field_result if defined $field_result;
            }
        }
        push @results, $result;
    }
    return {
        count       => scalar(@results)         + 0,
        total       => $collection->CountAll    + 0,
        per_page    => $collection->RowsPerPage + 0,
        page        => ($collection->FirstRow / $collection->RowsPerPage) + 1,
        items       => \@results,
    };
}

# Whitelist of methods which are allowed to be called on objects via
# the "fields" parameter. Only relevant for objects which don't
# have RT::Record as a base class.
our %expand_field_method_whitelist = (
    'RT::Lifecycle' => [qw(Name)],
    'RT::Lifecycle::Ticket' => [qw(Name)],
);

# Used in Serialize to allow additional fields to be selected ala JSON API on:
# http://jsonapi.org/examples/
sub expand_field {
    my $self  = shift;
    my $item  = shift;
    my $field = shift;
    my $param_prefix = shift || 'fields';

    my ($result, $obj);
    if (! $item->can('_Accessible')) {
        # Not an RT::Record derived object, so we need to check our whitelist
        # of allowed methods. Don't want any accidental calling of methods
        # That shouldn't be exposed.
        my $item_type = blessed($item);
        if (defined $item_type && defined $expand_field_method_whitelist{$item_type} && grep /^$field$/, @{$expand_field_method_whitelist{$item_type}}) {
            $result = $item->$field;
        }

    } elsif ($item->_Accessible($field => 'read')) {
        # RT::Record derived object, so we can check access permissions.

        if ($item->_Accessible($field => 'type') =~ /(datetime|timestamp)/i) {
            $result = format_datetime($item->$field);
        } elsif ($item->can($field . 'Obj')) {
            my $method = $field . 'Obj';
            $obj = $item->$method;
            if ($obj->can('UID')) {
                $result = expand_uid( $obj->UID );
            } else {
                $result = {};
            }
        } else {
            $result = $item->$field || '';
        }
    }

    if (defined $obj && defined $result) {
        my $param_field = $param_prefix . '[' . $field . ']';
        my @subfields = split(/,/, $self->request->param($param_field) || '');

        for my $subfield (@subfields) {
            my $subfield_result = $self->expand_field($obj, $subfield, $param_field);
            $result->{$subfield} = $subfield_result if defined $subfield_result;
        }
    }
    
    return $result;
}

# XXX TODO: Bulk update via DELETE/PUT on a collection resource?

sub charsets_provided { [ 'utf-8' ] }
sub default_charset   {   'utf-8'   }

sub content_types_provided { [
    { 'application/json' => 'to_json' },
] }

sub to_json {
    my $self = shift;
    my $status = $self->search;
    return $status if is_status_code($status);
    return \400 unless $status;
    return JSON::to_json($self->serialize, { pretty => 1 });
}

sub finish_request {
    my $self = shift;
    # Ensure the collection object is destroyed before the request finishes, for
    # any cleanup that may need to happen (i.e. TransactionBatch).
    $self->clear_collection;
    return $self->SUPER::finish_request(@_);
}

__PACKAGE__->meta->make_immutable;

1;

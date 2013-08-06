package RTx::REST::Resource::Collection;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RTx::REST::Resource';

use Scalar::Util qw( blessed );
use Web::Machine::Util qw( bind_path create_date );
use Encode qw( decode_utf8 );
use Module::Runtime qw( require_module );
use JSON ();
use RTx::REST::Util qw( serialize_record );

has 'collection_class' => (
    is          => 'ro',
    isa         => 'ClassName',
    required    => 1,
    lazy        => 1,
    default     => \&_collection_class,
);

has 'collection' => (
    is          => 'ro',
    isa         => 'RT::SearchBuilder',
    required    => 1,
    lazy_build  => 1,
);

sub _collection_class {
    my $self   = shift;
    my ($type) = blessed($self) =~ /::(\w+)$/;
    my $class  = "RT::$type";
    require_module($class);
    return $class;
}

sub _build_collection {
    my $self = shift;
    my $collection = $self->collection_class->new( $self->current_user );
    $self->limit_collection($collection);
    $self->paging($collection);
    return $collection;
}

sub paging {
    my ($self, $collection) = @_;
    my $per_page = $self->request->param('per_page') || 20;
       $per_page = 20  if $per_page <= 0;
       $per_page = 100 if $per_page > 100;
    $collection->RowsPerPage($per_page);

    my $page = $self->request->param('page') || 1;
       $page = 1 if $page < 0;
    $collection->GotoPage($page - 1);
}

sub limit_collection { }

sub serialize {
    my $self = shift;
    my $collection = $self->collection;
    my @results;

    while (my $item = $collection->Next) {
        push @results, serialize_record($item);
    }
    return {
        count       => scalar(@results)         + 0,
        total       => $collection->CountAll    + 0,
        per_page    => $collection->RowsPerPage + 0,
        page        => ($collection->FirstRow / $collection->RowsPerPage) + 1,
        items       => \@results,
    };
}

# XXX TODO: Bulk update via DELETE/PUT on a collection resource?

sub charsets_provided { [ 'utf-8' ] }
sub default_charset   {   'utf-8'   }

sub content_types_provided { [
    { 'application/json' => 'to_json' },
] }

sub to_json {
    my $self = shift;
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

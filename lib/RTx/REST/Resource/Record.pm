package RTx::REST::Resource::Record;
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

has 'record_class' => (
    is          => 'ro',
    isa         => 'ClassName',
    required    => 1,
    lazy        => 1,
    default     => \&_record_class,
);

has 'record' => (
    is          => 'ro',
    isa         => 'RT::Record',
    required    => 1,
    lazy_build  => 1,
);

sub _record_class {
    my $self   = shift;
    my ($type) = blessed($self) =~ /::(\w+)$/;
    my $class  = "RT::$type";
    require_module($class);
    return $class;
}

sub _build_record {
    my $self = shift;
    my $record = $self->record_class->new( $self->current_user );
    $record->Load( bind_path('/:id', $self->request->path_info) );
    return $record;
}

sub serialize {
    my $self = shift;
    my $data = serialize_record( $self->record );

    # Add the resource url for this record
    $data->{_url} = join "/", $self->base_uri, $self->record->id;

    return $data;
}

sub base_uri {
    $_[0]->request->base
}

sub resource_exists {
    $_[0]->record->id
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->record->id;

    my $can_see = $self->record->can("CurrentUserCanSee");
    return 1 if $can_see and not $self->record->$can_see();
    return 0;
}

sub last_modified {
    my $self = shift;
    return unless $self->record->_Accessible("LastUpdated" => "read");
    my $updated = $self->record->LastUpdatedObj->RFC2616
        or return;
    return create_date($updated);
}

sub allowed_methods {
    my $self = shift;
    my @ok = ('GET', 'HEAD');
    push @ok, 'DELETE'      if $self->DOES("RTx::REST::Resource::Record::Deletable");
    push @ok, 'PUT', 'POST' if $self->DOES("RTx::REST::Resource::Record::Writable");
    return \@ok;
}

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
    # Ensure the record object is destroyed before the request finishes, for
    # any cleanup that may need to happen (i.e. TransactionBatch).
    $self->clear_record;
    return $self->SUPER::finish_request(@_);
}

__PACKAGE__->meta->make_immutable;

1;

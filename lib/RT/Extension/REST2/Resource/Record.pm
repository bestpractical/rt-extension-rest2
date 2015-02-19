package RT::Extension::REST2::Resource::Record;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource';

use Web::Machine::Util qw( bind_path create_date );
use Module::Runtime qw( require_module );
use RT::Extension::REST2::Util qw(record_class record_type);

has 'record_class' => (
    is          => 'ro',
    isa         => 'ClassName',
    required    => 1,
    lazy_build  => 1,
);

has 'record' => (
    is          => 'ro',
    isa         => 'RT::Record',
    required    => 1,
    lazy_build  => 1,
);

sub _build_record_class {
    my $self = shift;
    my $class = record_class($self);
    require_module($class);
    return $class;
}

sub _build_record {
    my $self = shift;
    my $record = $self->record_class->new( $self->current_user );
    my ($type, $id) = bind_path('/:type/:id', $self->request->path_info);
    $record->Load($id) if $id;
    return $record;
}

sub base_uri {
    my $self = shift;
    my $base = $self->request->base;
    my $type = record_type($self);
    return $base . lc $type;
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
    my @ok;
    push @ok, 'GET', 'HEAD' if $self->DOES("RT::Extension::REST2::Resource::Record::Readable");
    push @ok, 'DELETE'      if $self->DOES("RT::Extension::REST2::Resource::Record::Deletable");
    push @ok, 'PUT', 'POST' if $self->DOES("RT::Extension::REST2::Resource::Record::Writable");
    return \@ok;
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

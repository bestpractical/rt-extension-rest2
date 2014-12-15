package RT::Extension::REST2::Resource::Record::Readable;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;

requires 'record';
requires 'record_class';
requires 'current_user';
requires 'base_uri';

use JSON ();
use RT::Extension::REST2::Util qw( serialize_record );

sub serialize {
    my $self = shift;
    my $data = serialize_record( $self->record );

    # Add the resource url for this record
    $data->{_url} = join "/", $self->base_uri, $self->record->id;

    return $data;
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

1;

package RT::Extension::REST2::Resource::Record::Readable;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;

requires 'record';
requires 'record_class';
requires 'current_user';
requires 'base_uri';

with 'RT::Extension::REST2::Resource::Record::WithETag';

use JSON ();
use RT::Extension::REST2::Util qw( serialize_record );
use Scalar::Util qw( blessed );

sub serialize {
    my $self = shift;
    my $record = $self->record;
    my $data = serialize_record($record);

    if ($self->does('RT::Extension::REST2::Resource::Record::Hypermedia')) {
        $data->{_hyperlinks} = $self->hypermedia_links;
    }

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

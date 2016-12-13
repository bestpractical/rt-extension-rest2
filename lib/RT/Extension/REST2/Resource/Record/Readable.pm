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
use RT::Extension::REST2::Util qw( serialize_record record_type );
use Scalar::Util qw( blessed );

sub serialize {
    my $self = shift;
    my $record = $self->record;
    my $data = serialize_record($record);

    $data->{_hyperlinks} = $self->hypermedia_links;

    return $data;
}

sub _self_link {
    my $self = shift;
    my $record = $self->record;

    my $class = blessed($record);
    $class =~ s/^RT:://;
    $class = lc $class;
    my $id = $record->id;

    return {
        ref     => 'self',
        type    => $class,
        id      => $id,
        _url    => RT::Extension::REST2->base_uri . "/$class/$id",
    };
}

sub hypermedia_links {
    my $self = shift;
    return [ $self->_self_link ];
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

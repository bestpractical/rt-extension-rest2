package RT::Extension::REST2::Resource::Record::Writable;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;
use JSON ();
use RT::Extension::REST2::Util qw( deserialize_record error_as_json );

with 'RT::Extension::REST2::Resource::Role::RequestBodyIsJSON'
     => { type => 'HASH' };

requires 'record';
requires 'record_class';

sub post_is_create            { 1 }
sub allow_missing_post        { 1 }
sub create_path_after_handler { 1 }
sub create_path {
    $_[0]->record->id || undef
}

sub content_types_accepted { [ {'application/json' => 'from_json'} ] }

sub from_json {
    my $self = shift;
    my $data = deserialize_record(
        $self->record,
        JSON::decode_json( $self->request->content ),
    );

    my $method = $self->request->method;
    return $method eq 'PUT'  ? $self->update_resource($data) :
           $method eq 'POST' ? $self->create_resource($data) :
                                                        \501 ;
}

sub update_record {
    my $self = shift;
    my $data = shift;

    # XXX TODO: ->Update doesn't handle roles
    my @results = $self->record->Update(
        ARGSRef       => $data,
        AttributesRef => [ $self->record->WritableAttributes ],
    );

    push @results, $self->_update_custom_fields($data);

    # XXX TODO: Figure out how to return success/failure?  Core RT::Record's
    # ->Update will need to be replaced or improved.
    $self->response->body( JSON::encode_json(\@results) );
    return;
}

sub _update_custom_fields {
    my $self = shift;
    my $data = shift;

    my $record = $self->record;
    my @results;

    foreach my $arg ( keys %$data ) {
        next unless $arg =~ /^CustomField-(\d+)$/i;
        my $cfid = $1;
        my $cf = $record->LoadCustomFieldByIdentifier($cfid);
        next unless $cf->ObjectTypeFromLookupType($cf->__Value('LookupType'))->isa(ref $record);

        if ($cf->SingleValue) {
            my $val = $data->{$arg};
            if (ref($val) eq 'ARRAY') {
                $val = $val->[0];
            }
            elsif (ref($val)) {
                die "Invalid value type for $arg";
            }

            my ($ok, $msg) = $record->AddCustomFieldValue(
                Field => $cf,
                Value => $val,
            );
            push @results, $msg;
        }
        else {
        }
    }

    return @results;
}

sub update_resource {
    my $self = shift;
    my $data = shift;

    if (not $self->resource_exists) {
        return error_as_json(
            $self->response,
            \404, "Resource does not exist; use POST to create");
    }

    return $self->update_record($data);
}

sub create_record {
    my $self = shift;
    my $data = shift;
    return $self->record->Create( %$data );
}

sub create_resource {
    my $self = shift;
    my $data = shift;

    if ($self->resource_exists) {
        return error_as_json(
            $self->response,
            \409, "Resource already exists; use PUT to update");
    }

    my ($ok, $msg) = $self->create_record($data);
    if ($ok) {
        return;
    } else {
        return error_as_json(
            $self->response,
            \400, $msg || "Create failed for unknown reason");
    }
}

1;

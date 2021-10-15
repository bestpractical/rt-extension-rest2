package RT::Extension::REST2::Resource::Record::Writable;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;
use JSON ();
use RT::Extension::REST2::Util qw( deserialize_record error_as_json expand_uid update_custom_fields update_role_members fix_custom_role_ids );
use List::MoreUtils 'uniq';

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

sub content_types_accepted { [ {'application/json' => 'from_json'}, { 'multipart/form-data' => 'from_multipart' } ] }

sub from_multipart {
    my $self = shift;
    my $json_str = $self->request->parameters->{JSON};
    return error_as_json(
        $self->response,
        \400, "Json is a required field for multipart/form-data")
            unless $json_str;

    my $json = JSON::decode_json($json_str);

    my $cfs = delete $json->{CustomFields};
    if ($cfs) {
        foreach my $id (keys %$cfs) {
            my $value = delete $cfs->{$id};

            if (ref($value) eq 'ARRAY') {
                my @values;
                foreach my $single_value (@$value) {
                    if ( ref $single_value eq 'HASH' && ( my $field_name = $single_value->{UploadField} ) ) {
                        my $file = $self->request->upload($field_name);
                        if ($file) {
                            open my $filehandle, '<', $file->tempname;
                            if (defined $filehandle && length $filehandle) {
                                my ( @content, $buffer );
                                while ( my $bytesread = read( $filehandle, $buffer, 72*57 ) ) {
                                    push @content, MIME::Base64::encode_base64($buffer);
                                }
                                close $filehandle;

                                push @values, {
                                    FileName    => $file->filename,
                                    FileType    => $file->headers->{'content-type'},
                                    FileContent => join("\n", @content),
                                };
                            }
                        }
                    }
                    else {
                        push @values, $single_value;
                    }
                }
                $cfs->{$id} = \@values;
            }
            elsif ( ref $value eq 'HASH' && ( my $field_name = $value->{UploadField} ) ) {
                my $file = $self->request->upload($field_name);
                if ($file) {
                    open my $filehandle, '<', $file->tempname;
                    if (defined $filehandle && length $filehandle) {
                        my ( @content, $buffer );
                        while ( my $bytesread = read( $filehandle, $buffer, 72*57 ) ) {
                            push @content, MIME::Base64::encode_base64($buffer);
                        }
                        close $filehandle;

                        $cfs->{$id} = {
                            FileName    => $file->filename,
                            FileType    => $file->headers->{'content-type'},
                            FileContent => join("\n", @content),
                        };
                    }
                }
            }
            else {
                $cfs->{$id} = $value;
            }
        }
        $json->{CustomFields} = $cfs;
    }

    return $self->from_json($json);
}

sub from_json {
    my $self = shift;
    my $params = shift || JSON::decode_json( $self->request->content );

    %$params = (
        %$params,
        %{ $self->request->query_parameters->mixed },
    );

    my $data = deserialize_record(
        $self->record,
        $params,
    );

    my $method = $self->request->method;
    return $method eq 'PUT'  ? $self->update_resource($data) :
           $method eq 'POST' ? $self->create_resource($data) :
                                                        \501 ;
}

sub update_record {
    my $self = shift;
    my $data = shift;

    # update_role_members wants custom role IDs (like RT::CustomRole-ID)
    # rather than role names.
    if ( $data->{CustomRoles} ) {
        %$data = ( %$data, %{ fix_custom_role_ids( $self->record, delete $data->{CustomRoles} ) } );
    }

    my @results = $self->record->Update(
        ARGSRef       => $data,
        AttributesRef => [ $self->record->WritableAttributes ],
    );

    push @results, update_custom_fields($self->record, $data->{CustomFields});
    push @results, update_role_members($self->record, $data);
    push @results, $self->_update_disabled($data->{Disabled})
      unless grep { $_ eq 'Disabled' } $self->record->WritableAttributes;
    push @results, $self->_update_privileged($data->{Privileged})
      unless grep { $_ eq 'Privileged' } $self->record->WritableAttributes;

    # XXX TODO: Figure out how to return success/failure?  Core RT::Record's
    # ->Update will need to be replaced or improved.
    return @results;
}

sub _update_disabled {
    my $self = shift;
    my $data = shift;
    my @results;

    my $record = $self->record;
    return unless defined $data and $data =~ /^[01]$/;

    return unless $record->can('SetDisabled');

    my ($ok, $msg) = $record->SetDisabled($data);
    push @results, $msg;

    return @results;
}

sub _update_privileged {
    my $self = shift;
    my $data = shift;
    my @results;

    my $record = $self->record;
    return unless defined $data and $data =~ /^[01]$/;

    return unless $record->can('SetPrivileged');

    my ($ok, $msg) = $record->SetPrivileged($data);
    push @results, $msg;

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

    my @results = $self->update_record($data);
    $self->response->body( JSON::encode_json(\@results) );
    return;
}

sub create_record {
    my $self = shift;
    my $data = shift;

    my $record = $self->record;
    my %args = %$data;

    my $cfs = delete $args{CustomFields};

    # Lookup CustomFields by name.
    if ($cfs) {
        foreach my $id (keys(%$cfs)) {
			my $value = delete $cfs->{$id};
            if ( ref($value) eq 'HASH' ) {
                foreach my $field ( 'FileName', 'FileType', 'FileContent' ) {
                    return ( 0, 0, "$field is a required field for Image/Binary ObjectCustomFieldValue" )
                        unless $value->{$field};
                }
                $value->{Value}        = delete $value->{FileName};
                $value->{ContentType}  = delete $value->{FileType};
                $value->{LargeContent} = MIME::Base64::decode_base64( delete $value->{FileContent} );
            }
            elsif ( ref($value) eq 'ARRAY' ) {
                my $i = 0;
                foreach my $single_value (@$value) {
                    if ( ref($single_value) eq 'HASH' ) {
                        foreach my $field ( 'FileName', 'FileType', 'FileContent' ) {
                            return ( 0, 0,
                                "$field is a required field for Image/Binary ObjectCustomFieldValue" )
                                unless $single_value->{$field};
                        }
                        $single_value->{Value}       = delete $single_value->{FileName};
                        $single_value->{ContentType} = delete $single_value->{FileType};
                        $single_value->{LargeContent}
                            = MIME::Base64::decode_base64( delete $single_value->{FileContent} );
                        $value->[$i] = $single_value;
                    }
                    $i++;
                }
            }
            $cfs->{$id} = $value;

            if ($id !~ /^\d+$/) {
                my $cf = $record->LoadCustomFieldByIdentifier($id);

                if ($cf->Id) {
                    $cfs->{$cf->Id} = $cfs->{$id};
                    delete $cfs->{$id};
                } else {
                    # I would really like to return an error message, but, how?
                    # RT appears to treat missing permission to a CF or
                    # non-existance of a CF as a non-fatal error.
                    RT->Logger->error( $record->loc( "Custom field [_1] not found", $id ) );
                }
            }
        }
    }

    # if a record class handles CFs in ->Create, use it (so it doesn't generate
    # spurious transactions and interfere with default values, etc). Otherwise,
    # add OCFVs after ->Create
    if ($record->isa('RT::Ticket') || $record->isa('RT::Asset')) {
        if ($cfs) {
            while (my ($id, $value) = each(%$cfs)) {
                delete $cfs->{$id};
                $args{"CustomField-$id"} = $value;
            }
        }
    }

    if ( $args{CustomRoles} ) {
        # RT::Ticket::Create wants custom role IDs (like RT::CustomRole-ID)
        # rather than role names.
        %args = ( %args, %{ fix_custom_role_ids( $record, delete $args{CustomRoles} ) } );
    }


    my $method = $record->isa('RT::Group') ? 'CreateUserDefinedGroup' : 'Create';
    my ($ok, @rest) = $record->$method(%args);

    if ($ok && $cfs) {
        update_custom_fields($record, $cfs);
    }

    return ($ok, @rest);
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
    if (ref($ok)) {
        return error_as_json(
            $self->response,
            $ok, $msg || "Create failed for unknown reason");
    }
    elsif ($ok) {
        my $response = $self->response;
        my $body = JSON::encode_json(expand_uid($self->record->UID));
        $response->content_type( "application/json; charset=utf-8" );
        $response->content_length( length $body );
        $response->body( $body );
        return;
    } else {
        return error_as_json(
            $self->response,
            \400, $msg || "Create failed for unknown reason");
    }
}

1;

package RT::Extension::REST2::Resource::Record::Writable;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;
use JSON ();
use RT::Extension::REST2::Util qw( deserialize_record error_as_json expand_uid );
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

sub content_types_accepted { [ {'application/json' => 'from_json'} ] }

sub from_json {
    my $self = shift;
    my $params = JSON::decode_json( $self->request->content );

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

    my @results = $self->record->Update(
        ARGSRef       => $data,
        AttributesRef => [ $self->record->WritableAttributes ],
    );

    push @results, $self->_update_custom_fields($data->{CustomFields});
    push @results, $self->_update_role_members($data);
    push @results, $self->_update_disabled($data->{Disabled});

    # XXX TODO: Figure out how to return success/failure?  Core RT::Record's
    # ->Update will need to be replaced or improved.
    return @results;
}

sub _update_custom_fields {
    my $self = shift;
    my $data = shift;

    my $record = $self->record;
    my @results;

    foreach my $cfid (keys %{ $data }) {
        my $val = $data->{$cfid};

        my $cf = $record->LoadCustomFieldByIdentifier($cfid);
        next unless $cf->ObjectTypeFromLookupType($cf->__Value('LookupType'))->isa(ref $record);

        if ($cf->SingleValue) {
            if (ref($val) eq 'ARRAY') {
                $val = $val->[0];
            }
            elsif (ref($val)) {
                die "Invalid value type for CustomField $cfid";
            }

            my ($ok, $msg) = $record->AddCustomFieldValue(
                Field => $cf,
                Value => $val,
            );
            push @results, $msg;
        }
        else {
            my %count;
            my @vals = ref($val) eq 'ARRAY' ? @$val : $val;
            for (@vals) {
                $count{$_}++;
            }

            my $ocfvs = $cf->ValuesForObject( $record );
            my %ocfv_id;
            while (my $ocfv = $ocfvs->Next) {
                my $content = $ocfv->Content;
                $count{$content}--;
                push @{ $ocfv_id{$content} }, $ocfv->Id;
            }

            # we want to provide a stable order, so first go by the order
            # provided in the argument list, and then for any custom fields
            # that are being removed, remove in sorted order
            for my $key (uniq(@vals, sort keys %count)) {
                my $count = $count{$key};
                if ($count == 0) {
                    # new == old, no change needed
                }
                elsif ($count > 0) {
                    # new > old, need to add new
                    while ($count-- > 0) {
                        my ($ok, $msg) = $record->AddCustomFieldValue(
                            Field => $cf,
                            Value => $key,
                        );
                        push @results, $msg;
                    }
                }
                elsif ($count < 0) {
                    # old > new, need to remove old
                    while ($count++ < 0) {
                        my $id = shift @{ $ocfv_id{$key} };
                        my ($ok, $msg) = $record->DeleteCustomFieldValue(
                            Field   => $cf,
                            ValueId => $id,
                        );
                        push @results, $msg;
                    }
                }
            }
        }
    }

    return @results;
}

sub _update_role_members {
    my $self = shift;
    my $data = shift;

    my $record = $self->record;

    return unless $record->DOES('RT::Record::Role::Roles');

    my @results;

    foreach my $role ($record->Roles) {
        next unless exists $data->{$role};

        # special case: RT::Ticket->Update already handles Owner for us
        next if $role eq 'Owner' && $record->isa('RT::Ticket');

        my $val = $data->{$role};

        if ($record->Role($role)->{Single}) {
            if (ref($val) eq 'ARRAY') {
                $val = $val->[0];
            }
            elsif (ref($val)) {
                die "Invalid value type for role $role";
            }

            my ($ok, $msg) = $record->AddWatcher(
                Type => $role,
                User => $val,
            );
            push @results, $msg;
        }
        else {
            my %count;
            my @vals;

            for (ref($val) eq 'ARRAY' ? @$val : $val) {
                my ($principal_id, $msg);

                if (/^\d+$/) {
                    $principal_id = $_;
                }
                elsif ($record->can('CanonicalizePrincipal')) {
                    ((my $principal), $msg) = $record->CanonicalizePrincipal(User => $_);
                    $principal_id = $principal->Id;
                }
                else {
                    my $user = RT::User->new($record->CurrentUser);
                    if (/@/) {
                        ((my $ok), $msg) = $user->LoadOrCreateByEmail( $_ );
                    } else {
                        ((my $ok), $msg) = $user->Load( $_ );
                    }
                    $principal_id = $user->PrincipalId;
                }

                if (!$principal_id) {
                    push @results, $msg;
                    next;
                }

                push @vals, $principal_id;
                $count{$principal_id}++;
            }

            my $group = $record->RoleGroup($role);
            my $members = $group->MembersObj;
            while (my $member = $members->Next) {
                $count{$member->MemberId}--;
            }

            # RT::Ticket has specialized methods
            my $add_method = $record->can('AddWatcher') ? 'AddWatcher' : 'AddRoleMember';
            my $del_method = $record->can('DeleteWatcher') ? 'DeleteWatcher' : 'DeleteRoleMember';

            # we want to provide a stable order, so first go by the order
            # provided in the argument list, and then for any role members
            # that are being removed, remove in sorted order
            for my $id (uniq(@vals, sort keys %count)) {
                my $count = $count{$id};
                if ($count == 0) {
                    # new == old, no change needed
                }
                elsif ($count > 0) {
                    # new > old, need to add new
                    while ($count-- > 0) {
                        my ($ok, $msg) = $record->$add_method(
                            Type        => $role,
                            PrincipalId => $id,
                        );
                        push @results, $msg;
                    }
                }
                elsif ($count < 0) {
                    # old > new, need to remove old
                    while ($count++ < 0) {
                        my ($ok, $msg) = $record->$del_method(
                            Type        => $role,
                            PrincipalId => $id,
                        );
                        push @results, $msg;
                    }
                }
            }
        }
    }

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

    my $method = $record->isa('RT::Group') ? 'CreateUserDefinedGroup' : 'Create';
    my ($ok, @rest) = $record->$method(%args);

    if ($ok && $cfs) {
        $self->_update_custom_fields($cfs);
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

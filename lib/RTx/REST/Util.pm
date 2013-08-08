package RTx::REST::Util;
use strict;
use warnings;

use JSON ();

use Sub::Exporter -setup => {
    exports => [qw[
        looks_like_uid
        expand_uid
        serialize_record
        deserialize_record
        error_as_json
    ]]
};

sub looks_like_uid {
    my $value = shift;
    return 0 unless ref $value eq 'HASH';
    return 0 unless $value->{type} and $value->{id} and $value->{url};
    return 1;
}

sub expand_uid {
    my $uid = shift;
       $uid = $$uid if ref $uid eq 'SCALAR';

    return if not defined $uid;

    my ($class, $rtname, $id) = $uid =~ /^([^-]+?)(?:-(.+?))?-(.+)$/;
    return unless $class and $id;

    $class =~ s/^RT:://;
    $class = lc $class;

    return {
        type    => $class,
        id      => $id,
        url     => "/$class/$id",
    };
}

sub serialize_record {
    my $record = shift;
    my %data   = $record->Serialize(@_);

    for my $column (grep !ref($data{$_}), keys %data) {
        if ($record->_Accessible($column => "read")) {
            # Replace values via the Perl API for consistency, access control,
            # and utf-8 handling.
            $data{$column} = $record->$column;

            # Promote raw SQL dates to a standard format
            if ($record->_Accessible($column => "type") =~ /(datetime|timestamp)/i) {
                my $date = RT::Date->new( $record->CurrentUser );
                $date->Set( Format => 'sql', Value => $data{$column} );
                $data{$column} = $date->W3CDTF( Timezone => 'UTC' );
            }
        } else {
            delete $data{$column};
        }
    }

    # Replace UIDs with object placeholders
    for my $uid (grep ref eq 'SCALAR', values %data) {
        $uid = expand_uid($uid);
    }

    # Include role members, if applicable
    if ($record->DOES("RT::Record::Role::Roles")) {
        for my $role ($record->Roles) {
            my $members = $data{$role} = [];
            my $group = $record->RoleGroup($role);
            my $gm = $group->MembersObj;
            while ($_ = $gm->Next) {
                push @$members, expand_uid($_->MemberObj->Object->UID);
            }

            # Avoid the extra array ref for single member roles
            $data{$role} = shift @$members
                if $group->SingleMemberRoleGroup;
        }
    }
    return \%data;
}

sub deserialize_record {
    my $record = shift;
    my $data   = shift;

    my $does_roles = $record->DOES("RT::Record::Role::Roles");

    # Sanitize input for the Perl API
    for my $field (sort keys %$data) {
        my $value = $data->{$field};
        next unless ref $value;
        if (looks_like_uid($value)) {
            # Deconstruct UIDs back into simple foreign key IDs, assuming it
            # points to the same record type (class).
            $data->{$field} = $value->{id} || 0;
        }
        elsif ($does_roles and $record->HasRole($field)) {
            my @members = ref $value eq 'ARRAY'
                ? @$value : $value;

            for my $member (@members) {
                $member = $member->{id} || 0
                    if looks_like_uid($member);
            }
            $data->{$field} = \@members;
        }
        else {
            RT->Logger->debug("Received unknown value via JSON for field $field: ".ref($value));
            delete $data->{$field};
        }
    }
    return $data;
}

sub error_as_json {
    my $response = shift;
    my $return = shift;
    $response->header( "Content-type" => "application/json; charset=utf-8" );
    $response->body( JSON::encode_json({ message => join "", @_ }) );
    return $return;
}

1;

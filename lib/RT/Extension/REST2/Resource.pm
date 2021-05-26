package RT::Extension::REST2::Resource;
use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
use RT::Extension::REST2::Util qw(expand_uid format_datetime custom_fields_for);

extends 'Web::Machine::Resource';

has 'current_user' => (
    is          => 'ro',
    isa         => 'RT::CurrentUser',
    required    => 1,
    lazy_build  => 1,
);

# XXX TODO: real sessions
sub _build_current_user {
    $_[0]->request->env->{"rt.current_user"} || RT::CurrentUser->new;
}

# Used in Serialize to allow additional fields to be selected ala JSON API on:
# http://jsonapi.org/examples/
sub expand_field {
    my $self  = shift;
    my $item  = shift;
    my $field = shift;
    my $param_prefix = shift || 'fields';

    my $result;
    if ($field eq 'CustomFields') {
        if (my $cfs = custom_fields_for($item)) {
            my %values;
            while (my $cf = $cfs->Next) {
                if (! defined $values{$cf->Id}) {
                    $values{$cf->Id} = {
                        %{ $self->_expand_object($cf, $field, $param_prefix) },
                        name   => $cf->Name,
                        values => [],
                    };
                }

                my $ocfvs = $cf->ValuesForObject($item);
                my $type  = $cf->Type;
                while ( my $ocfv = $ocfvs->Next ) {
                    my $content = $ocfv->Content;
                    if ( $type eq 'DateTime' ) {
                        $content = format_datetime($content);
                    }
                    elsif ( $type eq 'Image' or $type eq 'Binary' ) {
                        $content = {
                            content_type => $ocfv->ContentType,
                            filename     => $content,
                            _url         => RT::Extension::REST2->base_uri . "/download/cf/" . $ocfv->id,
                        };
                    }
                    push @{ $values{ $cf->Id }{values} }, $content;
                }
            }

            push @{ $result }, values %values if %values;
        }
    } elsif ($field eq 'CustomRoles') {
        if ( $item->DOES("RT::Record::Role::Roles") ) {
            my %data;
            for my $role ( $item->Roles( ACLOnly => 0 ) ) {
                next unless $role =~ /^RT::CustomRole-/;
                $data{$role} = [];

                my $group = $item->RoleGroup($role);
                if ( !$group->Id ) {
                    $data{$role} = $self->_expand_object( RT->Nobody->UserObj, $field, $param_prefix )
                        if $item->_ROLES->{$role}{Single};
                    next;
                }

                my $gms = $group->MembersObj;
                while ( my $gm = $gms->Next ) {
                    push @{ $data{$role} }, $self->_expand_object( $gm->MemberObj->Object, $field, $param_prefix );
                }

                # Avoid the extra array ref for single member roles
                $data{$role} = shift @{$data{$role}} if $group->SingleMemberRoleGroup;
            }
            return \%data;
        }
    } elsif ($field =~ /^RT::CustomRole-\d+$/) {
        if ( $item->DOES("RT::Record::Role::Roles") ) {
            my $result = [];

            my $group = $item->RoleGroup($field);
            if ( !$group->Id ) {
                $result = $self->_expand_object( RT->Nobody->UserObj, $field, $param_prefix )
                    if $item->_ROLES->{$field}{Single};
                next;
            }

            my $gms = $group->MembersObj;
            while ( my $gm = $gms->Next ) {
                push @$result, $self->_expand_object( $gm->MemberObj->Object, $field, $param_prefix );
            }

            # Avoid the extra array ref for single member roles
            $result = shift @$result if $group->SingleMemberRoleGroup;
            return $result;
        }
    } elsif ($item->can('_Accessible') && $item->_Accessible($field => 'read')) {
        # RT::Record derived object, so we can check access permissions.

        if ($item->_Accessible($field => 'type') =~ /(datetime|timestamp)/i) {
            $result = format_datetime($item->$field);
        } elsif ($item->can($field . 'Obj')) {
            my $method = $field . 'Obj';
            my $obj = $item->$method;
            if ( $obj->can('UID') ) {
                $result = $self->_expand_object( $obj, $field, $param_prefix );
            }
        }

        $result //= $item->$field;
    }

    return $result // '';
}

sub _expand_object {
    my $self         = shift;
    my $object       = shift;
    my $field        = shift;
    my $param_prefix = shift || 'fields';

    return unless $object->can('UID');

    my $result      = expand_uid( $object->UID ) or return;
    my $param_field = $param_prefix . '[' . $field . ']';
    my @subfields   = split( /,/, $self->request->param($param_field) || '' );

    for my $subfield (@subfields) {
        my $subfield_result = $self->expand_field( $object, $subfield, $param_field );
        $result->{$subfield} = $subfield_result if defined $subfield_result;
    }
    return $result;
}

__PACKAGE__->meta->make_immutable;

1;

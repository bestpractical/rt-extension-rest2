package RT::Extension::REST2::Resource::Assets;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/assets/?$},
        block => sub { { collection_class => 'RT::Assets' } },
    )
}

use RT::Extension::REST2::Util qw( expand_uid );

sub expand_field {
    my $self         = shift;
    my $item         = shift;
    my $field        = shift;
    my $param_prefix = shift;
    if ( $field =~ /^(Owner|HeldBy|Contact)/ ) {
        my $role    = $1;
        my $members = [];
        if ( my $group = $item->RoleGroup($role) ) {
            my $gms = $group->MembersObj;
            while ( my $gm = $gms->Next ) {
                push @$members, $self->_expand_object( $gm->MemberObj->Object, $field, $param_prefix );
            }
            $members = shift @$members if $group->SingleMemberRoleGroup;
        }
        return $members;
    }
    return $self->SUPER::expand_field( $item, $field, $param_prefix );
}

__PACKAGE__->meta->make_immutable;

1;

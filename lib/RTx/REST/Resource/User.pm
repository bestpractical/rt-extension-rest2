package RTx::REST::Resource::User;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RTx::REST::Resource';
with 'RTx::REST::Resource::Role::Record';
with 'RTx::REST::Resource::Role::Record::DisableOnDelete';
with 'RTx::REST::Resource::Role::Record::DisabledFromPrincipal';

around 'serialize_record' => sub {
    my $orig = shift;
    my $self = shift;
    my $data = $self->$orig(@_);
    $data->{Privileged} = $self->record->Privileged ? 1 : 0;
    return $data;
};

sub forbidden {
    my $self = shift;
    return 0 if not $self->record->id;
    return 0 if $self->record->id == $self->current_user->id;
    return 0 if $self->record->CurrentUserHasRight("AdminUsers");
    return 1;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

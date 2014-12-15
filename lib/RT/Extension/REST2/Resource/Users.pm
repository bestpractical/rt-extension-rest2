package RT::Extension::REST2::Resource::Users;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::QueryByJSON';

sub searchable_fields {
    my $class = $_[0]->collection->RecordClass;
    grep {
        $class->_Accessible($_ => "public")
    } $class->ReadableAttributes
}

sub forbidden {
    my $self = shift;
    return 0 if $self->current_user->HasRight(
        Right   => "AdminUsers",
        Object  => RT->System,
    );
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;

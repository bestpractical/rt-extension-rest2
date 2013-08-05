package RTx::REST::Resource::Record::DisabledFromPrincipal;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;

requires 'record';
requires 'record_class';

around 'serialize_record' => sub {
    my $orig = shift;
    my $self = shift;
    my $data = $self->$orig(@_);

    $data->{Disabled} = $self->record->PrincipalObj->Disabled
        unless exists $data->{Disabled};

    return $data;
};

1;

package RTx::REST::Resource::Record::Deletable;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;

requires 'record';
requires 'record_class';

around 'allowed_methods' => sub {
    my $orig = shift;
    my $self = shift;
    my $ok   = $self->$orig(@_);
    push @$ok, "DELETE"
        unless grep $_ eq "DELETE", @$ok;
    return $ok;
};

sub delete_resource {
    my $self = shift;
    my ($ok, $msg) = $self->record->Delete;
    RT->Logger->debug("Failed to delete ", $self->record_class, " #", $self->record->id, ": $msg")
        unless $ok;
    return $ok;
}

1;

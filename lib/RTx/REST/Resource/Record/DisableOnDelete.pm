package RTx::REST::Resource::Record::DisableOnDelete;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;

with 'RTx::REST::Resource::Record::Deletable';

sub delete_resource {
    my $self = shift;
    my ($ok, $msg) = $self->record->SetDisabled(1);
    RT->Logger->debug("Failed to disable ", $self->record_class, " #", $self->record->id, ": $msg")
        unless $ok;
    return $ok;
}

1;

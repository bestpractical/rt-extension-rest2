package RTx::REST::Resource::Record::Updatable;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;
use JSON ();
use RTx::REST::Util qw( looks_like_uid );

requires 'record';
requires 'record_class';

sub content_types_accepted { [ {'application/json' => 'from_json'} ] }

sub from_json {
    my $self = shift;
    $self->update_resource(
        JSON::from_json(
            $self->request->content,
        )
    );
}

sub update_resource {
    my $self = shift;
    my $data = shift;

    # Sanitize input
    for my $field (sort keys %$data) {
        my $value = $data->{$field};
        next unless ref $value;
        if (looks_like_uid($value)) {
            # Deconstruct UIDs back into simple foreign key IDs, assuming it
            # points to the same record type (class).
            $data->{$field} = $value->{id} || 0;
        }
        else {
            RT->Logger->debug("Received unknown value via JSON for field $field: ".ref($value));
            delete $data->{$field};
        }
    }

    my @results = $self->record->Update(
        ARGSRef       => $data,
        AttributesRef => [ $self->record->WritableAttributes ],
    );
    # XXX TODO: Figure out how to return success/failure?  Core RT::Record's
    # ->Update will need to be replaced or improved.
    return;
}

1;

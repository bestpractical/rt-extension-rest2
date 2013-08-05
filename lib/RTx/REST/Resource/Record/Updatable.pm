package RTx::REST::Resource::Record::Updatable;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;
use JSON ();

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
    my @results = $self->record->Update(
        ARGSRef       => $data,
        AttributesRef => [ $self->record->WritableAttributes ],
    );
    # XXX TODO: Figure out how to return success/failure?  Core RT::Record's
    # ->Update will need to be replaced or improved.
    return;
}

1;

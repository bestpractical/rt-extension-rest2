package RT::Extension::REST2::Resource::Record::WithETag;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;

requires 'record';

sub last_modified {
    my $self = shift;
    return unless $self->record->_Accessible("LastUpdated" => "read");
    return $self->record->LastUpdatedObj->W3CDTF( Timezone => 'UTC' );
}

sub generate_etag {
    my $self = shift;
    my $record = $self->record;

    if ($record->can('Transactions')) {
        my $txns = $record->Transactions;
        $txns->OrderByCols({ FIELD => 'id', ORDER => 'DESC' });
        return $txns->First->Id if $txns->Count;
    }

    # fall back to last-modified time, which is commonly accepted even
    # though there's a risk of race condition
    return $self->last_modified;
}

1;


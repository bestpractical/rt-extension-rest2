package RTx::REST::Util;
use strict;
use warnings;

use Sub::Exporter -setup => {
    exports => [qw[
        looks_like_uid
        expand_uid
        serialize_record
    ]]
};

sub looks_like_uid {
    my $value = shift;
    return 0 unless ref $value eq 'HASH';
    return 0 unless $value->{type} and $value->{id} and $value->{url};
    return 1;
}

sub expand_uid {
    my $uid = shift;
       $uid = $$uid if ref $uid eq 'SCALAR';

    return if not defined $uid;

    my ($class, $rtname, $id) = $uid =~ /^([^-]+?)(?:-(.+?))?-(.+)$/;
    return unless $class and $id;

    $class =~ s/^RT:://;
    $class = lc $class;

    return {
        type    => $class,
        id      => $id,
        url     => "/$class/$id",
    };
}

sub serialize_record {
    my $record = shift;
    my %data   = $record->Serialize(@_);

    for my $column (grep !ref($data{$_}), keys %data) {
        if ($record->_Accessible($column => "read")) {
            $data{$column} = $record->$column;

            # Promote raw SQL dates to a standard format
            if ($record->_Accessible($column => "type") =~ /(datetime|timestamp)/i) {
                my $date = RT::Date->new( $record->CurrentUser );
                $date->Set( Format => 'sql', Value => $data{$column} );
                $data{$column} = $date->W3CDTF( Timezone => 'UTC' );
            }
        } else {
            delete $data{$column};
        }
    }

    # Replace UIDs with object placeholders
    for my $uid (grep ref eq 'SCALAR', values %data) {
        $uid = expand_uid($uid);
    }
    return \%data;
}

1;

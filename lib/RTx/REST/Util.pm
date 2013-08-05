package RTx::REST::Util;
use strict;
use warnings;

use Sub::Exporter -setup => {
    exports => [qw[
        looks_like_uid
    ]]
};

sub looks_like_uid {
    my $value = shift;
    return 0 unless ref $value eq 'HASH';
    return 0 unless $value->{type} and $value->{id} and $value->{url};
    return 1;
}

1;

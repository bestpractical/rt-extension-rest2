package RT::Extension::REST2::Resource::Download::CF;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Record';

has 'content_type' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
    lazy_build  => 1,
);

sub _build_record_class { "RT::ObjectCustomFieldValue" }
sub _build_content_type {
    my $self = shift;
    return $self->record->ContentType || 'text/plain';
}

sub allowed_methods { [ 'GET', 'HEAD' ] }

sub content_types_provided { [
    { $_[0]->content_type => 'to_content' },
] }

sub charsets_provided {
    my $self = shift;
    # We need to serve both binary data (sans charset) and textual data (using
    # utf-8).  The RT::I18N helper is used in _DecodeLOB (via LargeContent),
    # and determines if the data returned by LargeContent has been decoded from
    # UTF-8 bytes to characters.  If not, the data remains bytes and we serve
    # no charset.
    if ( RT::I18N::IsTextualContentType( $self->content_type ) ) {
        return [ 'utf-8' ];
    } else {
        return [];
    }
}
sub default_charset { $_[0]->charsets_provided->[0] }

sub to_content {
    my $self = shift;
    return $self->record->LargeContent;
}

__PACKAGE__->meta->make_immutable;

1;

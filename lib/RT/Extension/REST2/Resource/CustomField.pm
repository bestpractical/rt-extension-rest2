package RT::Extension::REST2::Resource::CustomField;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Record';
with 'RT::Extension::REST2::Resource::Record::Readable',
     'RT::Extension::REST2::Resource::Record::Hypermedia'
        => { -alias => { hypermedia_links => '_default_hypermedia_links' } };

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/customfield/?$},
        block => sub { { record_class => 'RT::CustomField' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/customfield/(\d+)/?$},
        block => sub { { record_class => 'RT::CustomField', record_id => shift->pos(1) } },
    )
}

sub hypermedia_links {
    my $self = shift;
    my $links = $self->_default_hypermedia_links(@_);

    if ($self->record->IsSelectionType) {
        push @$links, {
            ref  => 'customfieldvalues',
            _url => RT::Extension::REST2->base_uri . "/customfield/" . $self->record->id . "/values",
        };
    }
    return $links;
}

__PACKAGE__->meta->make_immutable;

1;



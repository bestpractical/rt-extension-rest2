package RT::Extension::REST2::Resource::Transaction;
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
        regex => qr{^/transaction/?$},
        block => sub { { record_class => 'RT::Transaction' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/transaction/(\d+)$},
        block => sub { { record_class => 'RT::Transaction', record_id => shift->pos(1) } },
    )
}

sub hypermedia_links {
    my $self = shift;
    my $links = $self->_default_hypermedia_links(@_);

    my $class = 'transaction';
    my $id = $self->record->id;

    my $attachments = $self->record->Attachments;
    if ($attachments->Count) {
        push @$links, {
            ref  => 'attachments',
            _url => RT::Extension::REST2->base_uri . "/$class/$id/attachments",
        };
    }

    return $links;
}

__PACKAGE__->meta->make_immutable;

1;


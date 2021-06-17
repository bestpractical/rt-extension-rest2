package RT::Extension::REST2::Resource::TicketsBulk;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource';
with 'RT::Extension::REST2::Resource::Role::RequestBodyIsJSON' =>
  { type => 'ARRAY' };

use RT::Extension::REST2::Util qw(expand_uid);
use RT::Extension::REST2::Resource::Ticket;
use JSON ();

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new( regex => qr{^/tickets/bulk/?$} ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/tickets/bulk/(correspond|comment)$},
        block => sub { { type => shift->pos(1) } },
    )
}

has type => (
    is       => 'ro',
    isa      => 'Str',
);

sub post_is_create    { 1 }
sub create_path       { '/tickets/bulk' }
sub charsets_provided { [ 'utf-8' ] }
sub default_charset   { 'utf-8' }
sub allowed_methods   { [ 'PUT', 'POST' ] }

sub content_types_provided { [ { 'application/json' => sub {} } ] }
sub content_types_accepted { [ { 'application/json' => 'from_json' } ] }

sub from_json {
    my $self   = shift;
    my $params = JSON::decode_json( $self->request->content );

    my $method = $self->request->method;
    my @results;
    if ( $method eq 'PUT' ) {
        for my $param ( @$params ) {
            my $id = delete $param->{id};
            if ( $id && $id =~ /^\d+$/ ) {
                my $resource = RT::Extension::REST2::Resource::Ticket->new(
                    request      => $self->request,
                    response     => $self->response,
                    record_class => 'RT::Ticket',
                    record_id    => $id,
                );
                if ( $resource->resource_exists ) {
                    push @results, [ $id, $resource->update_record( $param ) ];
                    next;
                }
            }
            push @results, [ $id, 'Resource does not exist' ];
        }
    }
    else {
        for my $param ( @$params ) {
            if ( $self->type ) {
                my $id = delete $param->{id};
                if ( $id && $id =~ /^\d+$/ ) {
                    my $ticket = RT::Ticket->new($self->current_user);
                    $ticket->Load($id);
                    my $resource = RT::Extension::REST2::Resource::Message->new(
                        request      => $self->request,
                        response     => $self->response,
                        type         => $self->type,
                        record       => $ticket,
                    );

                    my @errors;

                    # Ported from RT::Extension::REST2::Resource::Message::from_json
                    if ( $param->{Attachments} ) {
                        foreach my $attachment ( @{ $param->{Attachments} } ) {
                            foreach my $field ( 'FileName', 'FileType', 'FileContent' ) {
                                push @errors, "$field is a required field for each attachment in Attachments"
                                    unless $attachment->{$field};
                            }
                        }
                    }

                    $param->{NoContent} = 1 unless $param->{Content};
                    if ( !$param->{NoContent} && !$param->{ContentType} ) {
                        push @errors, "ContentType is a required field for application/json";
                    }

                    if (@errors) {
                        push @results, [ $id, @errors ];
                        next;
                    }

                    my ( $return_code, @messages ) = $resource->_add_message(%$param);
                    push @results, [ $id, @messages ];
                }
                else {
                    push @results, [ $id, 'Resource does not exist' ];
                }
            }
            else {
                my $resource = RT::Extension::REST2::Resource::Ticket->new(
                    request      => $self->request,
                    response     => $self->response,
                    record_class => 'RT::Ticket',
                );
                my ( $ok, $msg ) = $resource->create_record($param);
                if ( ref($ok) || !$ok ) {
                    push @results, { message => $msg || "Create failed for unknown reason" };
                }
                else {
                    push @results, expand_uid( $resource->record->UID );
                }
            }
        }
    }

    $self->response->body( JSON::encode_json( \@results ) );
    return;
}

__PACKAGE__->meta->make_immutable;

1;

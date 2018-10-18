package RT::Extension::REST2::Resource::Message;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use MIME::Base64;

extends 'RT::Extension::REST2::Resource';
use RT::Extension::REST2::Util qw( error_as_json );

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/ticket/(\d+)/(correspond|comment)$},
        block => sub {
            my ($match, $req) = @_;
            my $ticket = RT::Ticket->new($req->env->{"rt.current_user"});
            $ticket->Load($match->pos(1));
            return { record => $ticket, type => $match->pos(2) },
        },
    );
}

has record => (
    is       => 'ro',
    isa      => 'RT::Record',
    required => 1,
);

has type => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has created_transaction => (
    is  => 'rw',
    isa => 'RT::Transaction',
);

sub post_is_create            { 1 }
sub create_path_after_handler { 1 }
sub allowed_methods           { ['POST'] }
sub charsets_provided         { [ 'utf-8' ] }
sub default_charset           { 'utf-8' }
sub content_types_provided    { [ { 'application/json' => sub {} } ] }
sub content_types_accepted    { [ { 'text/plain' => 'add_message' }, { 'text/html' => 'add_message' }, { 'application/json' => 'from_json' } ] }

sub from_json {
    my $self = shift;
    my $body = JSON::decode_json( $self->request->content );

    if ($body->{AttachmentsContents}) {
        foreach my $attachment (@{$body->{AttachmentsContents}}) {
            foreach my $field ('FileName', 'FileType', 'FileContent') {
                return error_as_json(
                    $self->response,
                    \400, "$field is a required field for each attachment in AttachmentsContents")
                unless $attachment->{$field};
            }
        }

        $body->{NoContent} = 1 unless $body->{Content};
    }

    if (!$body->{NoContent} && !$body->{ContentType}) {
        return error_as_json(
            $self->response,
            \400, "ContentType is a required field for application/json");
    }


    $self->add_message(%$body);
}

sub add_message {
    my $self = shift;
    my %args = @_;

    my $MIME = HTML::Mason::Commands::MakeMIMEEntity(
        Interface => 'REST',
        $args{NoContent} ? () : (Body => $args{Content} || $self->request->content),
        Type      => $args{ContentType} || $self->request->content_type,
        Subject   => $args{Subject},
    );

    # Process attachments
    foreach my $attachment (@{$args{AttachmentsContents}}) {
        $MIME->attach(
            Type => $attachment->{FileType},
            Filename => $attachment->{FileName},
            Data => MIME::Base64::decode_base64($attachment->{FileContent}),
        );
    }

    my ( $Trans, $msg, $TransObj ) ;

    if ($self->type eq 'correspond') {
        ( $Trans, $msg, $TransObj ) = $self->record->Correspond(
            MIMEObj   => $MIME,
            TimeTaken => ($args{TimeTaken} || 0),
        );
    }
    elsif ($self->type eq 'comment') {
        ( $Trans, $msg, $TransObj ) = $self->record->Comment(
            MIMEObj   => $MIME,
            TimeTaken => ($args{TimeTaken} || 0),
        );
    }
    else {
        return \400;
    }

    if (!$Trans) {
        return error_as_json(
            $self->response,
            \400, $msg || "Message failed for unknown reason");
    }

    $self->created_transaction($TransObj);
    $self->response->body(JSON::to_json([$msg], { pretty => 1 }));

    return 1;
}

sub create_path {
    my $self = shift;
    my $id = $self->created_transaction->Id;
    return "/transaction/$id";
}

__PACKAGE__->meta->make_immutable;

1;


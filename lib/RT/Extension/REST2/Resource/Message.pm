package RT::Extension::REST2::Resource::Message;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

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

    if (!$body->{ContentType}) {
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
        Body      => $args{Content}     || $self->request->content,
        Type      => $args{ContentType} || $self->request->content_type,
        Subject   => $args{Subject},
    );

    my ( $Trans, $msg, $TransObj );
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

    my ( $update_ret, $update_msg ) = $self->_update_txn_custom_fields(
        $TransObj, $args{TxnCustomFields} || $args{TransactionCustomFields} );
    $msg .= " - CF Processing Error: transaction custom fields not updated" unless $update_ret;

    $self->created_transaction($TransObj);
    $self->response->body(JSON::to_json([$msg], { pretty => 1 }));

    return 1;
}

sub _update_txn_custom_fields {
    my $self = shift;
    my $TransObj = shift;
    my $TxnCustomFields = shift;

    # generate a hash suitable for UpdateCustomFields
    # ie the keys are the "full names" of the custom fields
    my %txn_custom_fields;

    # Create an empty Transaction object to pass to GetCustomFieldInputName
    # UpdateCustomFields expects ARGS where the Txn input name doesn't have
    # an Id yet. It uses $self to determine which Txn to operate on.
    my $EmptyTxn = RT::Transaction->new( RT->SystemUser );

    foreach my $cf_name ( keys %{$TxnCustomFields} ) {
        my $cf_obj = $TransObj->LoadCustomFieldByIdentifier($cf_name);

        unless ( $cf_obj and $cf_obj->Id ) {
            RT->Logger->error( "Unable to load transaction custom field: $cf_name" );
            return ( 0, "Unable to load transaction custom field: $cf_name", undef );
        }

        my $txn_input_name = RT::Interface::Web::GetCustomFieldInputName(
                             Object      => $EmptyTxn,
                             CustomField => $cf_obj,
                             Grouping    => undef
        );

        $txn_custom_fields{$txn_input_name} = $TxnCustomFields->{$cf_name};
    }

    my ( $txn_ret, $txn_msg );
    if ( keys %$TxnCustomFields ) {
        ( $txn_ret, $txn_msg ) = $TransObj->UpdateCustomFields( %txn_custom_fields );

        if ( !$txn_ret ) {
            # the correspond/comment is already a success, the mails have been sent
            # so we can't return an error here
            RT->Logger->error( "Could not update transaction custom fields: $txn_msg" );
            return ( 0, $txn_msg );
        }
    }

    return ( 1, $txn_msg );
}

sub create_path {
    my $self = shift;
    my $id = $self->created_transaction->Id;
    return "/transaction/$id";
}

__PACKAGE__->meta->make_immutable;

1;


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

    # we use $txn_ret and $txn_msg so we don't interfere with the main $ret and $msg
    # see also comment below on the call to UpdateCustomFields
    my( $txn_ret, $txn_msg, $TxnCustomFields ) = $self->_massage_txn_custom_fields (
        $args{TxnCustomFields} || $args{TransactionCustomFields});
    if( ! $txn_ret ) {
        return error_as_json(
            $self->response,
            \400, $txn_msg);
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


    if( $TxnCustomFields ) {
        # transaction custom fields can be either in TxnCustomFields or in TransactionCustomFields
        # $msg is the result that will be returned, so we use $txn_msg in order not to clobber it
        ( $txn_ret, $txn_msg )= $TransObj->UpdateCustomFields( %$TxnCustomFields );
        RT->Logger->debug( "did the UpdateCustomFields with $TxnCustomFields->{'Object-RT::Transaction--CustomField-2'}, ret is [$txn_ret], message is [$txn_msg]");
        if (!$txn_ret) {
            # the correspond/comment is already a success, the mails have been sent
            # so we can't return an error here
            RT->Logger->warning( "could not update transaction custom fields: $msg" );
            $msg .= " - warning: custom fields not updated: $txn_msg";
        }
    }

    $self->created_transaction($TransObj);
    $self->response->body(JSON::to_json([$msg], { pretty => 1 }));

    return 1;
}

# takes a TxnCustomFields (or TransactionCustomFields) argument in
# returns 
#     a status code, 
#    a message (in case of error)
#     a hashref where the CF names are translated into the full
#        form Object-RT::Transaction--CustomField-<id> that can
#        be used by UpdateCustomFields
#        the value is undef if no argument was passed
sub _massage_txn_custom_fields {
    my $self = shift;
    my $txn_cf_by_name = shift;

    # if there are no transaction custom fields we're good
    if( ! $txn_cf_by_name ) {
        return ( 1, '', undef);
    }

    my $user = $self->request->env->{"rt.current_user"};

    # we need the queue to get the transaction custom fields that can apply to it
    my $queue= RT::Queue->new( $user );
    my( $ret, $msg)= $queue->Load( $self->record->Queue);
    if( ! $ret ) {
        RT->Logger->error( "cannot find ticket queue: $msg");
        return ( 0, $msg || "Cannot find ticket queue", undef );
    }

    # Check that the user can actually update the CFs
    unless(    $user->HasRight(Right => 'AdminUsers', Object => $RT::System)
            || $user->HasRight(
                   Right  => 'ModifyCustomField',
                   Object => $queue)
            || $user->HasRight(
                   Right  => 'ModifyTicket',
                   Object => $queue)
          ) {
        RT->Logger->error( "Cannot modify transaction custom fields");
        return ( 0, "Cannot modify transaction custom fields", undef );
    }

    # build a hash <custom_field_name> => <custom_field_record>
    my %txn_cf_name_to_id;
    my $cfs = $queue->TicketTransactionCustomFields;
    while( my $cf= $cfs->Next ) {
         $txn_cf_name_to_id{$cf->Name} = $cf;
         # also allow the full name  
         my $full_name = "Object-RT::Transaction--CustomField-" . $cf->Id;
         $txn_cf_name_to_id{$full_name} = $cf;
    }

    # generate a hash suitable for UpdateCustomFields
    # ie the keys are the "full names" of the custom fields 
    my $txn_custom_fields;
    foreach my $cf_name ( keys %$txn_cf_by_name) {
        my $cf = $txn_cf_name_to_id{$cf_name};
        if( ! $cf ) {
            RT->Logger->error ( "unknown transaction custom field: $cf_name" );
            return ( 0, "unknown transaction custom field: $cf_name", undef );
        }
        my $cf_full_name = "Object-RT::Transaction--CustomField-" . $cf->Id;
        $txn_custom_fields->{$cf_full_name} = $txn_cf_by_name->{$cf_name};
    }

    return ( 1, "custom fields updated", $txn_custom_fields );
}

sub _update_txn_custom_fields {
    my $self = shift;
    my %args = @_;

    return 1 if ! $args{TxnCustomFields};

    my( $ret, $msg ) = $args{TransObj}->UpdateCustomFields( %{$args{TxnCustomFields}} );
    if( ! $ret ) {
        RT->Logger->error( "cannot update transaction custom fields: $msg" );
        return ( 0, $msg || "Transaction Custom Fields update failed" );
    }

    return 1;
}

sub create_path {
    my $self = shift;
    my $id = $self->created_transaction->Id;
    return "/transaction/$id";
}

__PACKAGE__->meta->make_immutable;

1;


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


    # transaction custom fields can be either in TxnCustomFields or in TransactionCustomFields
    # $msg is the result that will be returned, so we use $txn_msg in order not to clobber it 
    my( $txn_ret, $txn_msg)= $self->_update_txn_custom_fields( 
        TransObj => $TransObj, 
        TxnCustomFields => $args{TxnCustomFields} || $args{TransactionCustomFields},
      );
    if (!$txn_ret) {
        return error_as_json(
            $self->response,
            \400, $msg || "Could not update transaction custom fields");
    }

    $self->created_transaction($TransObj);
    $self->response->body(JSON::to_json([$msg], { pretty => 1 }));

    return 1;
}

sub _update_txn_custom_fields {
    my $self = shift;
    my %args = @_;

    return 1 if ! $args{TxnCustomFields};

    # we need the queue to get the transaction custom fields that can apply to it
    my $queue= RT::Queue->new( $self->request->env->{"rt.current_user"} );
    my( $ret, $msg)= $queue->Load( $self->record->Queue);
    if( ! $ret ) {
        RT->Logger->error( "cannot find ticket queue: $msg");
        return ( 0, $msg || "Cannot find ticket queue" );
    }

    # build a hash <custom_field_name> => <custom_field_id>
    my %txn_cf_name_to_id;
    my $cfs = $queue->TicketTransactionCustomFields;
    while( my $cf= $cfs->Next ) {
         $txn_cf_name_to_id{$cf->Name} = $cf->Id;
         # also allow the full name  
         my $full_name = "Object-RT::Transaction--CustomField-" . $cf->Id;
         $txn_cf_name_to_id{$full_name} = $cf->Id; 
    }

    # generate a hash suitable for UpdateCustomFields
    # ie the keys are the "full names" of the custom fields 
    my %txn_custom_fields;
    my $txn_cf_by_name = $args{TxnCustomFields};
    foreach my $cf_name ( keys %$txn_cf_by_name) {
        my $cf_id = $txn_cf_name_to_id{$cf_name};
        if( ! $cf_id ) {
            RT->Logger->error ( "unknown transaction custom field: $cf_name");
            return ( 0, "unknown transaction custom field: $cf_name");
        }
        my $cf_full_name = "Object-RT::Transaction--CustomField-$cf_id";
        $txn_custom_fields{$cf_full_name} = $txn_cf_by_name->{$cf_name};
    }

    ( $ret, $msg) = $args{TransObj}->UpdateCustomFields( %txn_custom_fields);
    if( ! $ret ) {
        RT->Logger->error( "cannot update transaction custom fields: $msg");
        return ( 0, $msg || "Transaction Custom Fields update failed");
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


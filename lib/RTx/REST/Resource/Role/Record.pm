package RTx::REST::Resource::Role::Record;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;

use Scalar::Util qw( blessed );
use Web::Machine::Util qw( bind_path create_date );
use Encode qw( decode_utf8 );
use JSON ();

has 'record_class' => (
    is          => 'ro',
    isa         => 'ClassName',
    required    => 1,
    lazy        => 1,
    default     => \&_record_class,
);

has 'record' => (
    is          => 'ro',
    isa         => 'RT::Record',
    required    => 1,
    lazy_build  => 1,
);

has 'current_user' => (
    is          => 'ro',
    isa         => 'RT::CurrentUser',
    required    => 1,
    lazy_build  => 1,
);

sub _record_class {
    my $self   = shift;
    my ($type) = blessed($self) =~ /::(\w+)$/;
    my $class  = "RT::$type";
    $class->require;
    return $class;
}

sub _build_record {
    my $self = shift;
    my $record = $self->record_class->new( $self->current_user );
    $record->Load( bind_path('/:id', $self->request->path_info) );
    return $record;
}

# XXX TODO: real sessions
sub _build_current_user {
    $_[0]->request->env->{"rt.current_user"} || RT::CurrentUser->new;
}

sub serialize_record {
    my $self = shift;
    my %data = $self->record->Serialize(@_);

    for my $column (grep !ref($data{$_}), keys %data) {
        if ($self->record->_Accessible($column => "read")) {
            # XXX TODO: dates are in GMT, and should be marked as such
            $data{$column} = $self->record->$column;
        } else {
            delete $data{$column};
        }
    }

    # Replace UIDs with object placeholders
    for my $uid (grep ref eq 'SCALAR', values %data) {
        if (not defined $$uid) {
            $uid = undef;
            next;
        }

        my ($class, $rtname, $id) = $$uid =~ /^([^-]+?)(?:-(.+?))?-(.+)$/;
        next unless $class and $id;

        $class =~ s/^RT:://;
        $class = lc $class;

        $uid = {
            type    => $class,
            id      => $id,
            url     => "/$class/$id",
        };
    }
    return \%data;
}

sub resource_exists {
    $_[0]->record->id
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->record->id;

    my $can_see = $self->record->can("CurrentUserCanSee");
    return 1 if $can_see and not $self->record->$can_see();
    return 0;
}

sub last_modified {
    my $self = shift;
    return unless $self->record->_Accessible("LastUpdated" => "read");
    my $updated = $self->record->LastUpdatedObj->RFC2616
        or return;
    return create_date($updated);
}

sub charsets_provided { [ 'utf-8' ] }
sub default_charset   {   'utf-8'   }

sub content_types_provided { [
    { 'application/json' => 'to_json' },
] }

sub to_json {
    my $self = shift;
    return JSON::to_json($self->serialize_record, { pretty => 1 });
}

1;

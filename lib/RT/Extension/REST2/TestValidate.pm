# For testing override of validation methods

package RT::Extension::REST2::TestValidate;

sub validate_hook_before_create
{
    my ($self, $queue, $data) = @_;

    if ( $data->{'VALIDATE'} and $data->{'VALIDATE'} eq 'BAD_CREATE!' ) {
        return (400, 'Bad data');
    }

    return (200, '');
}

sub validate_hook_before_update
{
    my ($self, $ticket, $data) = @_;

    if ( $data->{'VALIDATE'} and $data->{'VALIDATE'} eq 'BAD_UPDATE!' ) {
        return (400, 'Bad data');
    }

    return (200, '');
}

1;

use strict;
use warnings;
package RTx::REST;

our $VERSION = '0.01';

use UNIVERSAL::require;
use Plack::Builder;
use Web::Machine;

=head1 NAME

RTx-REST - Adds a modern REST API to RT under /REST/2.0/

=cut

# XXX TODO: API doc

sub resource {
    my $class = "RTx::REST::Resource::$_[0]";
    $class->require or die $@;
    Web::Machine->new(
        resource => $class,
    )->to_app;
}

sub app {
    sub {
        # XXX TODO: logging of SQL queries in RT's framework for doing so
        # XXX TODO: Need a dispatcher?  Or do it inside resources?  Web::Simple?
        RT::ConnectToDatabase();
        my $dispatch = builder {
            # XXX TODO: better auth integration
            enable "Auth::Basic",
                realm         => RT->Config->Get("rtname") . " API",
                authenticator => sub {
                    my ($user, $pass, $env) = @_;
                    my $cu = RT::CurrentUser->new;
                    $cu->Load($user);

                    if ($cu->id and $cu->IsPassword($pass)) {
                        $env->{"rt.current_user"} = $cu;
                        return 1;
                    } else {
                        RT->Logger->error("FAILED LOGIN for $user from $env->{REMOTE_ADDR}");
                        return 0;
                    }
                };
            mount "/\L$_"   => resource($_)
                for qw(Ticket Queue User);
            mount "/"       => sub { [ 404, ['Content-type' => 'text/plain'], ['Unknown resource'] ] };
        };
        $dispatch->(@_);
    }
}

# Called by RT::Interface::Web::Handler->PSGIApp
sub PSGIWrap {
    my ($class, $app) = @_;
    builder {
        mount "/REST/2.0"   => $class->app;
        mount "/"           => $app;
    };
}

=head1 INSTALLATION 

=over

=item C<perl Makefile.PL>

=item C<make>

=item C<make install>

May need root permissions

=item Edit your F</opt/rt4/etc/RT_SiteConfig.pm>

Add this line:

    Set(@Plugins, qw(RTx::REST));

or add C<RTx::REST> to your existing C<@Plugins> line.

=item Clear your mason cache

    rm -rf /opt/rt4/var/mason_data/obj

=item Restart your webserver

=back

=head1 AUTHOR

Thomas Sibley <trs@bestpractical.com>

=head1 BUGS

All bugs should be reported via email to
L<bug-RTx-REST@rt.cpan.org|mailto:bug-RTx-REST@rt.cpan.org>
or via the web at
L<rt.cpan.org|http://rt.cpan.org/Public/Dist/Display.html?Name=RTx-REST>.

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2013 by Best Practical Solutions

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut

1;

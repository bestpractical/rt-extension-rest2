package RT::Extension::REST2::Resource::Collection::Search;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;

requires 'collection';
use Regexp::Common qw/delimited/;

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my %args = @_;

    if ( my $id = $args{request}->param('search') ) {
        my $search = RT::Extension::REST2::Resource::Search::_load_search( $args{request}, $id );

        if ( $search && $search->Id ) {
            if ( !defined $args{query} && !defined $args{request}->param('query') ) {
                if ( my $query = $search->GetParameter('Query') ) {
                    $args{request}->parameters->set( query => $query );
                }
            }

            if ( !defined $args{order} && !defined $args{request}->param('order') ) {
                if ( my $order = $search->GetParameter('Order') ) {
                    $args{request}->parameters->set( order => split /\|/, $order );
                }
            }

            if ( !defined $args{orderby} && !defined $args{request}->param('orderby') ) {
                if ( my $orderby = $search->GetParameter('OrderBy') ) {
                    $args{request}->parameters->set( orderby => split /\|/, $orderby );
                }
            }

            if ( !defined $args{per_page} && !defined $args{request}->param('per_page') ) {
                if ( my $per_page = $search->GetParameter('RowsPerPage') ) {
                    $args{request}->parameters->set( per_page => $per_page );
                }
            }

            if ( !defined $args{fields} && !defined $args{request}->param('fields') ) {
                if ( my $format = $search->GetParameter('Format') ) {
                    my @attrs;

                    # Main logic is copied from share/html/Elements/CollectionAsTable/ParseFormat
                    while ( $format =~ /($RE{delimited}{-delim=>qq{\'"}}|[{}\w.]+)/go ) {
                        my $col    = $1;
                        my $colref = {};

                        if ( $col =~ /^$RE{quoted}$/o ) {
                            substr( $col, 0,  1 ) = "";
                            substr( $col, -1, 1 ) = "";
                            $col =~ s/\\(.)/$1/g;
                        }

                        while ( $col =~ s{/(STYLE|CLASS|TITLE|ALIGN|SPAN|ATTRIBUTE):([^/]*)}{}i ) {
                            $colref->{ lc $1 } = $2;
                        }

                        unless ( length $col ) {
                            $colref->{'attribute'} = '' unless defined $colref->{'attribute'};
                        }
                        elsif ( $col =~ /^__(NEWLINE|NBSP)__$/ || $col =~ /^(NEWLINE|NBSP)$/ ) {
                            $colref->{'attribute'} = '';
                        }
                        elsif ( $col =~ /__(.*?)__/io ) {
                            while ( $col =~ s/^(.*?)__(.*?)__//o ) {
                                $colref->{'last_attribute'} = $2;
                            }
                            $colref->{'attribute'} = $colref->{'last_attribute'}
                                unless defined $colref->{'attribute'};
                        }
                        else {
                            $colref->{'attribute'} = $col
                                unless defined $colref->{'attribute'};
                        }

                        if ( $colref->{'attribute'} ) {
                            push @attrs, $colref->{'attribute'};
                        }
                    }

                    my %fields;

                    if (@attrs) {
                        my $record_class = $args{collection_class}->RecordClass;
                        while ( my $attr = shift @attrs ) {
                            if ( $attr =~ /^(Requestors?|AdminCc|Cc|CustomRole\.\{.+?\})(?:\.(.+))?/ ) {
                                my $role  = $1;
                                my $field = $2;

                                if ( $role eq 'Requestors' ) {
                                    $role = 'Requestor';
                                }
                                elsif ( $role =~ /^CustomRole\.\{(.+?)\}/ ) {
                                    my $name        = $1;
                                    my $custom_role = RT::CustomRole->new( $args{request}->env->{"rt.current_user"} );
                                    $custom_role->Load($name);
                                    if ( $custom_role->Id ) {
                                        $role = $custom_role->GroupType;
                                    }
                                    else {
                                        next;
                                    }
                                }

                                $fields{$role} = 1;
                                if ($field) {
                                    $field = 'CustomFields' if $field =~ /^CustomField\./;
                                    $args{request}->parameters->set(
                                        "fields[$role]" => join ',',
                                        $field,
                                        $args{request}->parameters->get("fields[$role]") || ()
                                    );
                                }
                            }
                            elsif ( $attr =~ /^CustomField\./ ) {
                                $fields{CustomFields} = 1;
                            }
                            elsif ( $attr
                                =~ /^(?:RefersTo|ReferredToBy|DependsOn|DependedOnBy|MemberOf|Members|Parents|Children)$/
                                )
                            {
                                $fields{_hyperlinks} = 1;
                            }
                            elsif ( $record_class->can('_Accessible') && $record_class->_Accessible( $attr => 'read' ) )
                            {
                                $fields{$attr} = 1;
                            }
                            elsif ( $attr =~ s/Relative$// ) {

                                # Date fields like LastUpdatedRelative
                                push @attrs, $attr;
                            }
                            elsif ( $attr =~ s/Name$// ) {

                                # Fields like OwnerName, QueueName
                                push @attrs, $attr;
                                $args{request}->parameters->set(
                                    "fields[$attr]" => join ',',
                                    'Name',
                                    $args{request}->parameters->get("fields[$attr]") || ()
                                );
                            }
                        }
                    }

                    $args{request}->parameters->set( 'fields' => join ',', sort keys %fields );
                }
            }
        }
    }

    return $class->$orig( %args );
};

1;

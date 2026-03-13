# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package ORM::DSL;
use strict;
use warnings;
use experimental 'signatures';


# Package variables from ORM::Model that we need to access
our ( %_has_many, %_belongs_to, %_validations );

=pod

=head1 NAME

ORM::DSL - DSL functions for ORM models

=head1 SYNOPSIS

    package MyApp::Model::User;
    use Moo;
    extends 'ORM::Model';
    use ORM::DSL;
    
    tablename 'users';
    
    column id      => (is => 'rw', isa => 'Int', primary_key => 1);
    column name    => (is => 'rw', isa => 'Str', required => 1);
    column email   => (is => 'rw', isa => 'Str', unique => 1);
    
    belongs_to company => (is => 'rw', isa => 'MyApp::Model::Company');
    has_many   orders  => (is => 'rw', isa => 'MyApp::Model::Order');
    
    validates email => (format => qr/@/);
    
    1;

=head1 DESCRIPTION

This module exports DSL functions for defining ORM models.

Use this module after C<use Moo; extends 'ORM::Model'> to get the
column, tablename, has_many, belongs_to, and validates functions.

=head1 FUNCTIONS

All functions are exported to the caller's namespace when this module is used.

=cut

sub import {
    my ($class, @args) = @_;
    my $caller = caller();
    load_into($caller, @args);
}

sub load_into {
    my ($caller, @args) = @_;
    no strict 'refs';

    # Export column function
    *{"${caller}::column"} = sub ($name, @opts) {
        my %opts = @opts;
        my $pkg  = $caller;

        # Store in both the package-specific hash AND ORM::Model for attribute lookup
        ${$caller . "::_columns"}->{$pkg} //= [];
        push @{ ${$caller . "::_columns"}->{$pkg} }, $name;
        
        $ORM::Model::_columns{$pkg} //= [];
        push @{$ORM::Model::_columns{$pkg}}, $name;

        # This is interesting in that it is a global registry 
        # of all columns defined in all the model packages
        $ORM::Model::COLUMN_META{$pkg}{$name} = \%opts;

        if ( $opts{primary_key} ) {
            $ORM::Model::_primary_key{$pkg} = $name;
        }

        my $is = $opts{is} // 'rw';
        my $validations = $ORM::Model::_validations{$pkg}{$name} // {};
        my $col_isa     = lc($opts{isa} // '');
        my $col_length  = $opts{length};
        my $is_bool     = ($col_isa eq 'bool') ? 1 : 0;

        if ( $is eq 'rw' ) {
            *{"${pkg}::${name}"} = sub {
                my ( $self, $val ) = @_;
                if ( defined $val ) {
                    if (exists $validations->{required}
                        && $validations->{required} && !defined $val)
                    {
                        die "$name is required";
                    }
                    if (exists $validations->{format} && defined $val) {
                        unless ($val =~ $validations->{format}) {
                            die "Invalid $name: $val";
                        }
                    }
                    if ($is_bool) {
                        $val = $val ? 1 : 0;
                    }
                    if (defined $col_length && length($val) > $col_length) {
                        die "$name exceeds maximum length of $col_length";
                    }
                    $self->{$name} = $val;
                    return $self;
                }
                if ($is_bool && !exists $self->{$name}
                    && defined $opts{default})
                {
                    return $opts{default} ? 1 : 0;
                }
                return $self->{$name};
            };
        } else {
            *{"${pkg}::${name}"} = sub {
                my ($self) = @_;
                return $self->{$name};
            };
        }

        return;
    };

    # Export tablename function
    *{"${caller}::tablename"} = sub ($name=undef) {
        no strict 'refs';
        my $pkg = caller; 
        if (defined $name) {
            ${ "${pkg}::_tablename" } = $name;
        }
        return $name;
    };

    # Export has_many function
    *{"${caller}::has_many"} = sub ($name, %opts) {
        my $pkg = caller;

        # Interesting that the ORM::Model package maintains this association spec
        $_has_many{$pkg}{$name} = \%opts;
        
        my $isa = $opts{isa};
        my $foreign_key = $opts{foreign_key};
        
        unless ($foreign_key) {
            $foreign_key = "${name}_id";
        }
        
        *{"${pkg}::${name}"} = sub ($self) {
            my $model_class = $isa;
            my $fk = $foreign_key;
            my $pk = $self->primary_key;
            my $pk_val = $self->$pk;
            
            return () unless defined $pk_val;
            
            my $result = $model_class->where({ $fk => $pk_val });
            return wantarray ? $result->all : $result;
        };
        
        my $create_method = "create_$name";
        *{"${pkg}::$create_method"} = sub ($self, @args) {
            my $model_class = $isa;
            my $pk = $self->primary_key;
            my $pk_val = $self->$pk;
            
            die "Cannot create related object without primary key" unless defined $pk_val;
            
            my %data = @args == 1 && ref $args[0] eq 'HASH' ? %{$args[0]} : @args;
            $data{$foreign_key} = $pk_val;
            return $model_class->create(\%data);
        };
        
        return;
    };

    # Export belongs_to function
    *{"${caller}::belongs_to"} = sub ($name, %opts) {
        my $pkg = caller;
        $_belongs_to{$pkg}{$name} = \%opts;
        
        my $isa = $opts{isa};
        my $foreign_key = $opts{foreign_key} // "${name}_id";
        
        *{"${pkg}::${name}"} = sub ($self) {
            my $model_class = $isa;
            my $fk = $foreign_key;
            my $fk_val = $self->$fk;
            
            return undef unless defined $fk_val;
            
            return $model_class->find($fk_val);
        };
        
        return;
    };

    # Export validates function
    *{"${caller}::validates"} = sub ($name, %opts) {
        my $pkg = caller;
        $_validations{$pkg}{$name} = \%opts;
        return;
    };
}

1;

=pod

=head1 EXAMPLE

    package MyApp::Model::User;
    use Moo;
    extends 'ORM::Model';
    use ORM::DSL;
    
    tablename 'users';
    
    column id         => (is => 'rw', isa => 'Int', primary_key => 1);
    column name       => (is => 'rw', isa => 'Str', required => 1);
    column email      => (is => 'rw', isa => 'Str', unique => 1);
    column age        => (is => 'rw', isa => 'Int');
    column active     => (is => 'rw', isa => 'Int', default => 1);
    column created_at => (is => 'rw', isa => 'Str');
    column updated_at => (is => 'rw', isa => 'Str');
    
    belongs_to company => (is => 'rw', isa => 'MyApp::Model::Company');
    has_many   orders  => (is => 'rw', isa => 'MyApp::Model::Order');
    
    validates email => (format => qr/@/);
    
    1;

=head1 SEE ALSO

L<ORM::Model>

=cut

# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package Durance::DSL;
use strict;
use warnings;
use experimental 'signatures';


# Package variables from Durance::Model that we need to access
our ( %_has_many, %_has_one, %_belongs_to, %_validations );

=pod

=head1 NAME

Durance::DSL - DSL functions for ORM models

=head1 SYNOPSIS

    package MyApp::Model::User;
    use Moo;
    extends 'Durance::Model';
    use Durance::DSL;
    
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

Use this module after C<use Moo; extends 'Durance::Model'> to get the
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

        # Store in both the package-specific hash AND Durance::Model for attribute lookup
        ${$caller . "::_columns"}->{$pkg} //= [];
        push @{ ${$caller . "::_columns"}->{$pkg} }, $name;
        
        $Durance::Model::_columns{$pkg} //= [];
        push @{$Durance::Model::_columns{$pkg}}, $name;

        # This is interesting in that it is a global registry 
        # of all columns defined in all the model packages
        $Durance::Model::COLUMN_META{$pkg}{$name} = \%opts;

        if ( $opts{primary_key} ) {
            $Durance::Model::_primary_key{$pkg} = $name;
        }

        my $is = $opts{is} // 'rw';
        my $col_isa     = lc($opts{isa} // '');
        my $col_length  = $opts{length};
        my $is_bool     = ($col_isa eq 'bool') ? 1 : 0;

        if ( $is eq 'rw' ) {
            *{"${pkg}::${name}"} = sub {
                my ( $self, $val ) = @_;
                
                # Look up validations at RUNTIME, not definition time
                my $validations = $Durance::Model::_validations{$pkg}{$name} // {};
                
                # Check required validation BEFORE defined check
                if (exists $validations->{required}
                    && $validations->{required} && !defined $val)
                {
                    die "$name is required";
                }
                
                if ( defined $val ) {
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

        # Interesting that the Durance::Model package maintains this association spec
        $_has_many{$pkg}{$name} = \%opts;
        
        # Tag with relationship type
        $_has_many{$pkg}{$name}{_relationship_type} = 'has_many';
        
        my $isa = $opts{isa};
        my $foreign_key = $opts{foreign_key};
        
        unless ($foreign_key) {
            # Default foreign key is derived from the parent class's singular name
            # e.g., Company has_many employees -> employees.company_id
            # Extract short name from package: MyApp::Model::Company -> Company -> company
            my $parent_name = $pkg;
            $parent_name =~ s/.+::(.+?)$/$1/;
            $parent_name = lc($parent_name);
            $foreign_key = "${parent_name}_id";
        }
        
        $_has_many{$pkg}{$name}{foreign_key} = $foreign_key;
        
        *{"${pkg}::${name}"} = sub ($self) {
            # Check for preloaded data first
            my $key = "_preloaded_$name";
            if (exists $self->{$key}) {
                return $self->{$key};
            }
            
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

    # Export has_one function
    *{"${caller}::has_one"} = sub ($name, %opts) {
        my $pkg = caller;

        # Store in has_one registry
        $_has_one{$pkg}{$name} = \%opts;
        
        # Tag with relationship type
        $_has_one{$pkg}{$name}{_relationship_type} = 'has_one';
        
        my $isa = $opts{isa};
        my $foreign_key = $opts{foreign_key};
        
        unless ($foreign_key) {
            # Default foreign key is derived from the parent class's singular name
            # e.g., User has_one profile -> profiles.user_id
            # Extract short name from package: MyApp::Model::User -> User -> user
            my $parent_name = $pkg;
            $parent_name =~ s/.+::(.+?)$/$1/;
            $parent_name = lc($parent_name);
            $foreign_key = "${parent_name}_id";
        }
        
        $_has_one{$pkg}{$name}{foreign_key} = $foreign_key;
        
        # has_one accessor returns single object (not array like has_many)
        *{"${pkg}::${name}"} = sub ($self) {
            # Check for preloaded data first
            my $key = "_preloaded_$name";
            if (exists $self->{$key}) {
                return $self->{$key};
            }
            
            my $model_class = $isa;
            my $fk = $foreign_key;
            my $pk = $self->primary_key;
            my $pk_val = $self->$pk;
            
            return undef unless defined $pk_val;
            
            # Return single object (not array like has_many)
            return $model_class->where({ $fk => $pk_val })->first;
        };
        
        return;
    };

    # Export belongs_to function
    *{"${caller}::belongs_to"} = sub ($name, %opts) {
        my $pkg = caller;
        $_belongs_to{$pkg}{$name} = \%opts;
        
        # Tag with relationship type
        $_belongs_to{$pkg}{$name}{_relationship_type} = 'belongs_to';
        
        my $isa = $opts{isa};
        my $foreign_key = $opts{foreign_key} // "${name}_id";
        
        *{"${pkg}::${name}"} = sub ($self) {
            # Check for preloaded data first
            my $key = "_preloaded_$name";
            if (exists $self->{$key}) {
                return $self->{$key};
            }
            
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
        $Durance::Model::_validations{$pkg}{$name} = \%opts;
        return;
    };
}

1;

=pod

=head1 EXAMPLE

    package MyApp::Model::User;
    use Moo;
    extends 'Durance::Model';
    use Durance::DSL;
    
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

L<Durance::Model>

=cut

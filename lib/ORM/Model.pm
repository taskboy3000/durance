package ORM::Model;
use strict;
use warnings;
use base 'ORM::Base';

our %COLUMN_META;
our ( %_columns, %_primary_key );

sub import {
    my ($class) = @_;
    my $caller = caller;

    ORM::Base::import($caller);

    {
        no strict 'refs';
        @{"${caller}::ISA"} = ('ORM::Base');
        push @{"${caller}::ISA"}, 'ORM::Model';
    }

    no strict 'refs';
    *{"${caller}::column"} = sub {
        my ( $name, @opts ) = @_;
        my %opts = @opts;
        my $pkg  = caller;

        $_columns{$pkg} //= [];
        push @{ $_columns{$pkg} }, $name;

        $ORM::Base::COLUMN_META{$pkg}{$name} = \%opts;

        if ( $opts{primary_key} ) {
            $_primary_key{$pkg} = $name;
        }

        my $is = $opts{is} // 'rw';

        if ( $is eq 'rw' ) {
            *{"${pkg}::${name}"} = sub {
                my ( $self, $val ) = @_;
                if ( defined $val ) {
                    $self->{$name} = $val;
                    return $self;
                }
                return $self->{$name};
            };
        }
        else {
            *{"${pkg}::${name}"} = sub {
                my ($self) = @_;
                return $self->{$name};
            };
        }

        return;
    };
}

sub attributes {
    my ($class) = @_;
    return $ORM::Base::_columns{$class} // [];
}

sub primary_key {
    my ($class) = @_;
    return $ORM::Base::_primary_key{$class} // 'id';
}

sub column_meta {
    my ( $class, $column ) = @_;
    return $ORM::Base::COLUMN_META{$class}{$column} // {};
}

1;

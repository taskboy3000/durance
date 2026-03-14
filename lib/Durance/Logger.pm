# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package Durance::Logger;
use strict;
use warnings;
use experimental 'signatures';
use Moo;

sub log ($self, $message) {
    return unless $ENV{ORM_SQL_LOGGING};
    warn "[" . scalar(localtime) . "][$$] $message\n";
}

1;

=pod

=head1 NAME

Durance::Logger - Simple SQL logging to STDERR

=head1 SYNOPSIS

    use Durance::Logger;
    
    my $logger = Durance::Logger->new;
    $logger->log("SELECT * FROM users WHERE id = ?");
    
    # Enable logging via environment variable:
    # $ ORM_SQL_LOGGING=1 perl script.pl

=head1 DESCRIPTION

Durance::Logger provides simple, lightweight logging to STDERR for SQL statements
and diagnostic messages. Logging is controlled by the C<ORM_SQL_LOGGING>
environment variable and is disabled by default.

Each log message includes:
- Timestamp (from localtime)
- Process ID ($$)
- Message text

This class is designed to be subclassed by users who want custom logging
behavior. Override the C<log()> method or use a different C<_build_logger>
in your ORM classes.

=head1 METHODS

=head2 log($message)

Log a message to STDERR. The message is prefixed with timestamp and process ID.

Only outputs when C<ORM_SQL_LOGGING=1> is set in the environment.

Example output:
    [Fri Mar 13 17:30:45 2026][12345] SELECT * FROM users WHERE id = ? [42]

=head1 ENVIRONMENT VARIABLES

=over 4

=item ORM_SQL_LOGGING

Set to 1 to enable logging. Example:

    $ ORM_SQL_LOGGING=1 perl script.pl

=back

=head1 SUBCLASSING

You can override the C<log()> method to implement custom logging:

    package MyApp::CustomLogger;
    use Moo;
    extends 'Durance::Logger';
    
    sub log ($self, $message) {
        # Custom logging logic here
        print STDERR "CUSTOM: $message\n";
    }

Then in your ORM classes, override C<_build_logger>:

    has 'logger' => (is => 'lazy');
    sub _build_logger ($self) {
        return MyApp::CustomLogger->new;
    }

=head1 SEE ALSO

L<Durance::Model>, L<Durance::ResultSet>, L<Durance::Schema>

=cut

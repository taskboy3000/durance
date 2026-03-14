#!/usr/bin/env perl
# Test suite for Durance::Logger

use strict;
use warnings;
use experimental 'signatures';

use FindBin;
use File::Basename;
use lib dirname($FindBin::Bin) . '/lib';

use Durance::Logger;
use Test2::V0;

# Test Durance::Logger
subtest 'Durance::Logger - Core Functionality' => sub {
    my $logger = Durance::Logger->new;
    ok($logger->isa('Durance::Logger'), 'Logger instantiates correctly');
};

subtest 'Durance::Logger - log() method exists' => sub {
    my $logger = Durance::Logger->new;
    ok($logger->can('log'), 'Logger has log() method');
};

subtest 'Durance::Logger - log() with ORM_SQL_LOGGING disabled' => sub {
    # Ensure environment variable is not set
    local $ENV{ORM_SQL_LOGGING} = 0;
    
    my $logger = Durance::Logger->new;
    
    # Capture STDERR to verify nothing is logged
    my $stderr_output = '';
    open my $stderr_fh, '>', \$stderr_output or die "Cannot capture STDERR: $!";
    my $old_stderr = *STDERR;
    *STDERR = $stderr_fh;
    
    $logger->log("Test message");
    
    *STDERR = $old_stderr;
    close $stderr_fh;
    
    is($stderr_output, '', 'No output when ORM_SQL_LOGGING=0');
};

subtest 'Durance::Logger - log() with ORM_SQL_LOGGING enabled' => sub {
    local $ENV{ORM_SQL_LOGGING} = 1;
    
    my $logger = Durance::Logger->new;
    
    # Capture STDERR
    my $stderr_output = '';
    open my $stderr_fh, '>', \$stderr_output or die "Cannot capture STDERR: $!";
    my $old_stderr = *STDERR;
    *STDERR = $stderr_fh;
    
    $logger->log("Test message");
    
    *STDERR = $old_stderr;
    close $stderr_fh;
    
    # Verify output contains key elements
    ok($stderr_output, 'Output is produced when ORM_SQL_LOGGING=1');
    like($stderr_output, qr/Test message/, 'Message text is logged');
    like($stderr_output, qr/\[\d+\]/, 'PID is logged');
};

subtest 'Durance::Logger - log() includes timestamp' => sub {
    local $ENV{ORM_SQL_LOGGING} = 1;
    
    my $logger = Durance::Logger->new;
    
    my $stderr_output = '';
    open my $stderr_fh, '>', \$stderr_output or die "Cannot capture STDERR: $!";
    my $old_stderr = *STDERR;
    *STDERR = $stderr_fh;
    
    $logger->log("Test");
    
    *STDERR = $old_stderr;
    close $stderr_fh;
    
    # Timestamp format: "Day Mon DD HH:MM:SS YYYY" or similar
    like($stderr_output, qr/\d{1,2}:\d{2}:\d{2}/, 'Timestamp with HH:MM:SS included');
};

subtest 'Durance::Logger - log() includes PID' => sub {
    local $ENV{ORM_SQL_LOGGING} = 1;
    
    my $logger = Durance::Logger->new;
    
    my $stderr_output = '';
    open my $stderr_fh, '>', \$stderr_output or die "Cannot capture STDERR: $!";
    my $old_stderr = *STDERR;
    *STDERR = $stderr_fh;
    
    $logger->log("Test");
    
    *STDERR = $old_stderr;
    close $stderr_fh;
    
    like($stderr_output, qr/\[$$\]/, 'Current process ID included in brackets');
};

subtest 'Durance::Logger - Multiple calls to log()' => sub {
    local $ENV{ORM_SQL_LOGGING} = 1;
    
    my $logger = Durance::Logger->new;
    
    my $stderr_output = '';
    open my $stderr_fh, '>', \$stderr_output or die "Cannot capture STDERR: $!";
    my $old_stderr = *STDERR;
    *STDERR = $stderr_fh;
    
    $logger->log("Message 1");
    $logger->log("Message 2");
    $logger->log("Message 3");
    
    *STDERR = $old_stderr;
    close $stderr_fh;
    
    my @lines = split /\n/, $stderr_output;
    # Remove empty trailing line if present
    @lines = grep { length($_) > 0 } @lines;
    
    is(scalar @lines, 3, 'Three log messages produced');
    like($lines[0], qr/Message 1/, 'First message correct');
    like($lines[1], qr/Message 2/, 'Second message correct');
    like($lines[2], qr/Message 3/, 'Third message correct');
};

subtest 'Durance::Logger - log() with SQL statement' => sub {
    local $ENV{ORM_SQL_LOGGING} = 1;
    
    my $logger = Durance::Logger->new;
    
    my $stderr_output = '';
    open my $stderr_fh, '>', \$stderr_output or die "Cannot capture STDERR: $!";
    my $old_stderr = *STDERR;
    *STDERR = $stderr_fh;
    
    my $sql = "SELECT * FROM users WHERE id = ?";
    $logger->log("SQL (0.123 ms): $sql [42]");
    
    *STDERR = $old_stderr;
    close $stderr_fh;
    
    like($stderr_output, qr/SELECT \* FROM users/, 'SQL statement logged');
    like($stderr_output, qr/0\.123 ms/, 'Timing information logged');
    like($stderr_output, qr/\[42\]/, 'Parameters logged');
};

subtest 'Durance::Logger - Subclassable for custom behavior' => sub {
    # Create a custom logger subclass
    package TestCustomLogger;
    use Moo;
    extends 'Durance::Logger';
    
    has 'logged_messages' => (is => 'rw', default => sub { [] });
    
    sub log ($self, $message) {
        push @{$self->logged_messages}, $message;
    }
    
    package main;
    
    my $custom_logger = TestCustomLogger->new;
    $custom_logger->log("Message 1");
    $custom_logger->log("Message 2");
    
    is(scalar @{$custom_logger->logged_messages}, 2, 'Custom logger received messages');
    is($custom_logger->logged_messages->[0], "Message 1", 'First message captured');
    is($custom_logger->logged_messages->[1], "Message 2", 'Second message captured');
};

done_testing();

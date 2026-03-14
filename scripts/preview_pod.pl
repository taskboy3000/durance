#!/usr/bin/env perl
# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
=pod

=head1 NAME

preview_pod.pl - Preview POD documentation from Perl modules

=head1 SYNOPSIS

    ./scripts/preview_pod.pl lib/ORM/Model.pm
    ./scripts/preview_pod.pl lib/ORM/ResultSet.pm | less
    ./scripts/preview_pod.pl lib/ORM/*.pm

=head1 DESCRIPTION

Converts POD (Plain Old Documentation) in Perl modules to plain text for easy
preview. Uses pod2text for formatting.

=head1 USAGE

    # View a single file
    ./scripts/preview_pod.pl lib/ORM/Model.pm

    # View multiple files
    ./scripts/preview_pod.pl lib/ORM/*.pm

    # Pipe to less for interactive viewing
    ./scripts/preview_pod.pl lib/ORM/ResultSet.pm | less

    # Save to file
    ./scripts/preview_pod.pl lib/ORM/Model.pm > /tmp/model_docs.txt

=cut

use strict;
use warnings;
use experimental 'signatures';
use Pod::Text;
use File::Spec;

my @files = @ARGV;

if (!@files) {
    print STDERR "Usage: $0 <file.pm> [<file.pm> ...]\n";
    print STDERR "       $0 lib/ORM/*.pm\n";
    exit 1;
}

for my $file (@files) {
    if (!-f $file) {
        warn "File not found: $file\n";
        next;
    }

    # Print separator if processing multiple files
    if (@files > 1) {
        print "=" x 80 . "\n";
        print "File: $file\n";
        print "=" x 80 . "\n\n";
    }

    # Convert POD to text
    my $parser = Pod::Text->new(
        indent   => 2,
        width    => 78,
        sentence => 0,
    );

    $parser->parse_from_file($file);
    print "\n";
}

1;

#!/usr/bin/env perl
use strict;
use warnings;

use Test2::V0;
use File::Temp qw(tempfile);
use Carp qw(croak);

subtest 'opencode --version works and returns valid format' => sub {
    my $version = `opencode --version 2>&1`;
    my $exit_code = $? >> 8;
    chomp $version;
    
    is($exit_code, 0, 'opencode --version exits successfully');
    like($version, qr/^\d+\.\d+\.\d+$/, 'version is in semver format');
    is($version, '1.2.24', 'version matches expected value');
};

subtest 'opencode-version tool returns valid JSON' => sub {
    my $home = $ENV{HOME} // $ENV{USERPROFILE} // '';
    my $tool_path = "$home/.config/opencode/tools/opencode-version.ts";
    
    ok(-e $tool_path, 'tool file exists');
    
    open my $fh, '<', $tool_path or croak "Cannot open $tool_path: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    
    like($content, qr/execute.*opencode --version/s, 'tool executes opencode --version');
    like($content, qr/return.*version/s, 'tool returns version');
};

done_testing;

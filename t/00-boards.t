#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin../../lib";

plan skip_all =>
  'set LEANKIT_USER, LEANKIT_PASSWORD, LEANKIT_ACCOUNT to enable these tests'
  unless $ENV{LEANKIT_USER}
  && $ENV{LEANKIT_PASSWORD}
  && $ENV{LEANKIT_ACCOUNT};

diag("Testing LeanKit API");

ok_use('Net::LeanKit');
use Net::LeanKit;

my $username = $ENV{LEANKIT_USER};
my $password = $ENV{LEANKIT_PASSWORD};
my $account = $ENV{LEANKIT_ACCOUNT};

my $lk = Net::LeanKit->new(
    username => $username,
    password => $password,
    account  => $account
);

ok(length $lk->getBoards, "Found some boards.");

done_testing();

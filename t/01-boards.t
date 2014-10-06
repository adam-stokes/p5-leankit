#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

plan skip_all =>
  'set LEANKIT_EMAIL, LEANKIT_PASSWORD, LEANKIT_ACCOUNT to enable these tests'
  unless $ENV{LEANKIT_EMAIL}
  && $ENV{LEANKIT_PASSWORD}
  && $ENV{LEANKIT_ACCOUNT};

diag("Testing LeanKit API");

use_ok('Net::LeanKit');

my $email = $ENV{LEANKIT_EMAIL};
my $password = $ENV{LEANKIT_PASSWORD};
my $account = $ENV{LEANKIT_ACCOUNT};

my $lk = Net::LeanKit->new(
    email => $email,
    password => $password,
    account  => $account
);

ok(length $lk->getBoards, "Found some boards.");
ok($lk->getBoardByName('Solutions Engineering - Openstack'), 'Querying board by title');

done_testing();

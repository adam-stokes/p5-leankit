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

my $boards = $lk->getBoards;
my $boardId = $boards->[0]->{Id};
ok(length $boards, "Found some boards.");
ok($lk->getBoard($boardId), "Got board: ".$boardId);
ok($lk->getBoardIdentifiers($boardId), "Got identifiers: ".$boardId);
ok($lk->getBoardBacklogLanes($boardId), "got backlog lanes");
ok($lk->getBoardArchiveLanes($boardId), "got archive lanes");
ok($lk->getBoardByName('Solutions Engineering - Openstack'), 'Querying board by title');

done_testing();

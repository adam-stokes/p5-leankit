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
my $board = $lk->getBoard($boardId);

ok(length $boards, "Found some boards.");
ok($board, "Got board");
ok(length $board->{Lanes}, "Board lanes exists");
ok(length $lk->getBoardIdentifiers($boardId), "Got identifiers: ".$boardId);
ok(length $lk->getBoardBacklogLanes($boardId), "got backlog lanes");
ok(length $lk->getBoardArchiveLanes($boardId), "got archive lanes");
ok(length $lk->getBoardArchiveCards($boardId), "got archive cards");

my $getBoardByName = $lk->getBoardByName($board->{Title});
ok(defined($getBoardByName->{Title}), "Matched board title");
my $cards = $lk->searchCards($boardId, { Page => 1, MaxResults => 3, OrderBy => "CreatedOn"});
ok($cards->{TotalResults} > 0, "Found Cards");
ok(defined($cards->{Results}->[0]->{Title}), "A title exists in cards");

my $cardType = $board->{CardTypes}->[0]->{Id};
my $laneId = $board->{Lanes}->[0]->{Id};
my $newCard = {
    Title          => 'API Test',
    TypeId         => $cardType,
    Priority       => 1,
    ExternalCardId => '010101'
};
$lk->addCard($boardId, $laneId, 0, $newCard);

$newCard = $lk->getCardByExternalId($boardId, '010101');
ok($lk->getCard($boardId, $newCard->[0]->{Id}), 'Found card by cardId');
ok($newCard->[0]->{Title} eq 'API Test', 'Found created card by title');
ok($lk->deleteCard($boardId, $newCard->[0]->{Id}), "Deleted card");

done_testing();

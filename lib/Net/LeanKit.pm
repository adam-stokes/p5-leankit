package Net::LeanKit;

# ABSTRACT: A perl library for Leankit.com

use strict;
use warnings;
use Carp;
use HTTP::Tiny;
use JSON::Any;
use URI::Escape;
use namespace::clean;

=head1 SYNOPSIS

  use Net::LeanKit;
  my $lk = Net::LeanKit(email => 'user\@.mail.com',
                        password => 'pass',
                        account => 'my company');
  $lk->getBoards;

=attr email

Login email

=attr password

Password

=attr account

Account name in which your account is under, usually a company name.

=cut

use Class::Tiny qw( email password account ), {
    boardIdentifiers => sub { +{} },
    defaultWipOverrideReason =>
      sub {'WIP Override performed by external system'},
    headers => sub {
        {   'Accept'       => 'application/json',
            'Content-type' => 'application/json'
        };
    },
    ua => sub { HTTP::Tiny->new },
    j  => sub { JSON::Any->new }
};

sub BUILD {
    my ($self, $args) = @_;
    for my $req (qw/ email password account/) {
        croak "$req attribute required" unless defined $self->$req;
    }
}


=method get(STR endpoint)

GET requests to leankit

=cut

sub get {
    my ($self, $endpoint) = @_;
    my $auth = uri_escape(sprintf("%s:%s", $self->email, $self->password));
    my $url = sprintf('https://%s@%s.leankit.com/kanban/api/%s',
        $auth, $self->account, $endpoint);

    my $r = $self->ua->get($url, {headers => $self->headers});
    croak "$r->{status} $r->{reason}" unless $r->{success};
    my $content = $r->{content} ? $self->j->decode($r->{content}) : 1;
    return $content->{ReplyData}->[0];
}

=method post(STR endpoint, HASH body)

POST requests to leankit

=cut

sub post {
    my ($self, $endpoint, $body) = @_;
    my $auth = uri_escape(sprintf("%s:%s", $self->email, $self->password));
    my $url = sprintf('https://%s@%s.leankit.com/kanban/api/%s',
        $auth, $self->account, $endpoint);

    my $post = {headers => $self->headers};
    if (defined $body) {
        $post->{content} = $self->j->encode($body);
    }
    else {
        $post->{headers}->{'Content-Length'} = '0';
    }

    my $r = $self->ua->post($url, $post);
    croak "$r->{status} $r->{reason}" unless $r->{success};
    return $self->j->decode($r->{content});
}


=method getBoards

Returns list of boards

=cut

sub getBoards {
    my ($self) = @_;
    my $res = $self->get('boards');
    return $res;
}


=method getNewBoards

Returns list of latest created boards

=cut

sub getNewBoards {
    my ($self) = @_;
    return $self->get('ListNewBoards');
}

=method getBoard(INT id)

Gets leankit board by id

=cut

sub getBoard {
    my ($self, $id) = @_;
    my $boardId = sprintf('boards/%s', $id);
    return $self->get($boardId);
}


=method getBoardByName(STR boardName)

Finds a board by name

=cut

sub getBoardByName {
    my ($self, $boardName) = @_;
    foreach my $board (@{$self->getBoards}) {
        next unless $board->{Title} =~ /$boardName/i;
        return $board;
    }
}

=method getBoardIdentifiers(INT boardId)

Get board identifiers

=cut

sub getBoardIdentifiers {
    my ($self, $boardId) = @_;

    # use cache
    if ($self->boardIdentifiers->{$boardId}) {
        return $self->boardIdentifiers->{$boardId};
    }

    my $board = sprintf('board/%s/GetBoardIdentifiers', $boardId);
    my $data = $self->get($board);
    $self->boardIdentifiers->{$boardId} = $data;
    return $self->boardIdentifiers->{$boardId};
}

=method getBoardBacklogLanes(INT boardId)

Get board back log lanes

=cut

sub getBoardBacklogLanes {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/backlog", $boardId);
    return $self->get($board);
}

=method getBoardArchiveLanes(INT boardId)

Get board archive lanes

=cut

sub getBoardArchiveLanes {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/archive", $boardId);
    return $self->get($board);
}

=method getBoardArchiveCards(INT boardId)

Get board archive cards

=cut

sub getBoardArchiveCards {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/archivecards", $boardId);
    return $self->get($board);
}

=method getNewerIfExists(INT boardId, INT version)

Get newer board version if exists

=cut

sub getNewerIfExists {
    my ($self, $boardId, $version) = @_;
    my $board = sprintf("board/%s/boardversion/%s/getnewerifexists", $boardId,
        $version);
    return $self->get($board);
}

=method getBoardHistorySince(INT boardId, INT version)

Get newer board history

=cut

sub getBoardHistorySince {
    my ($self, $boardId, $version) = @_;
    my $board = sprintf("board/%s/boardversion/%s/getboardhistorysince",
        $boardId, $version);
    return $self->get($board);
}

=method getBoardUpdates(INT boardId, INT version)

Get board updates

=cut

sub getBoardUpdates {
    my ($self, $boardId, $version) = @_;
    my $board =
      sprintf("board/%s/boardversion/%s/checkforupdates", $boardId, $version);
    return $self->get($board);
}

=method getCard(INT boardId, INT cardId)

Get specific card for board

=cut

sub getCard {
    my ($self, $boardId, $cardId) = @_;
    my $board = sprintf("board/%s/getcard/%s", $boardId, $cardId);
    return $self->get($board);
}

=method getCardByExternalId(INT boardId, INT cardId)

Get specific card for board by an external id

=cut

sub getCardByExternalId {
    my ($self, $boardId, $externalCardId) = @_;
    my $board = sprintf("board/%s/getcardbyexternalid/%s",
        $boardId, uri_escape($externalCardId));
    return $self->get($board);
}


=method addCard(INT boardId, INT laneId, INT position, HASHREF card)

Add a card to the board/lane specified. The card hash usually contains

  { TypeId => 1,
    Title => 'my card title',
    ExternCardId => DATETIME,
    Priority => 1
  }

=cut

sub addCard {
    my ($self, $boardId, $laneId, $position, $card) = @_;
    $card->{UserWipOverrideComment} = $self->defaultWipOverrideReason;
    my $newCard =
      sprintf('board/%s/AddCardWithWipOvveride/Lane/%s/Position/%s',
        $boardId, $laneId, $position);
    return $self->post($newCard, $card);
}

=method addCards(INT boardId, ARRAYREF cards)

Add multiple cards to the board/lane specified. The card hash usually contains

  { TypeId => 1,
    Title => 'my card title',
    ExternCardId => DATETIME,
    Priority => 1
  }

=cut

sub addCards {
    my ($self, $boardId, $cards) = @_;
    my $newCard =
      sprintf('board/%s/AddCards?wipOverrideComment="%s"',
        $boardId, $self->defaultWipOverrideReason);
    return $self->post($newCard, $cards);
}


=method moveCard(INT boardId, INT cardId, INT toLaneId, INT position)

Moves card to different lanes

=cut

sub moveCard {
    my ($self, $boardId, $cardId, $toLaneId, $position) = @_;
    my $moveCard =
      sprintf('board/%s/movecardwithwipoverride/%s/lane/%s/position/%s',
        $boardId, $cardId, $toLaneId, $position);
    my $params = {comment => $self->defaultWipOverrideReason};
    return $self->post($moveCard, $params);
}


=method moveCardByExternalId(INT boardId, INT externalCardId, INT toLaneId, INT position)

Moves card to different lanes by externalId

=cut

sub moveCardByExternalId {
    my ($self, $boardId, $externalCardId, $toLaneId, $position) = @_;
    my $moveCard = sprintf(
        'board/%s/movecardbyexternalid/%s/lane/%s/position/%s',
        $boardId, uri_escape($externalCardId),
        $toLaneId, $position
    );
    my $params = {comment => $self->defaultWipOverrideReason};
    return $self->post($moveCard, $params);
}


=method moveCardToBoard(INT cardId, INT destinationBoardId)

Moves card to another board

=cut

sub moveCardToBoard {
    my ($self, $cardId, $destinationBoardId) = @_;
    my $moveCard = sprintf('card/movecardtoanotherboard/%s/%s',
        $cardId, $destinationBoardId);
    my $params = {};
    return $self->post($moveCard, $params);
}


=method updateCard(INT boardId, HASHREF card)

Update a card

=cut

sub updateCard {
    my ($self, $boardId, $card) = @_;
    $card->{UserWipOverrideComment} = $self->defaultWipOverrideReason;
    my $updateCard = sprintf('board/%s/UpdateCardWithWipOverride');
    return $self->post($updateCard, $card);
}

1;

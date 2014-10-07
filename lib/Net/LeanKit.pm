package Net::LeanKit;

# ABSTRACT: A perl library for Leankit.com

use strict;
use warnings;
use Carp;
use HTTP::Tiny;
use JSON::Any;
use URI::Escape;

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


=method get

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

=method post

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

=method getBoard

Gets leankit board by id

=cut

sub getBoard {
    my ($self, $id) = @_;
    my $boardId = sprintf('boards/%s', $id);
    return $self->get($boardId);
}


=method getBoardByName

Finds a board by name

=cut

sub getBoardByName {
    my ($self, $boardName) = @_;
    foreach my $board (@{$self->getBoards}) {
        next unless $board->{Title} =~ /$boardName/i;
        return $board;
    }
}

=method getBoardIdentifiers

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

=method getBoardBacklogLanes

Get board back log lanes

=cut

sub getBoardBacklogLanes {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/backlog", $boardId);
    return $self->get($board);
}

=method getBoardArchiveLanes

Get board archive lanes

=cut

sub getBoardArchiveLanes {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/archive", $boardId);
    return $self->get($board);
}

=method getBoardArchiveCards

Get board archive cards

=cut

sub getBoardArchiveCards {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/archivecards", $boardId);
    return $self->get($board);
}

=method getNewerIfExists

Get newer board version if exists

=cut

sub getNewerIfExists {
    my ($self, $boardId, $version) = @_;
    my $board = sprintf("board/%s/boardversion/%s/getnewerifexists", $boardId,
        $version);
    return $self->get($board);
}

=method getBoardHistorySince

Get newer board history

=cut

sub getBoardHistorySince {
    my ($self, $boardId, $version) = @_;
    my $board = sprintf("board/%s/boardversion/%s/getboardhistorysince",
        $boardId, $version);
    return $self->get($board);
}

=method getBoardUpdates

Get board updates

=cut

sub getBoardUpdates {
    my ($self, $boardId, $version) = @_;
    my $board =
      sprintf("board/%s/boardversion/%s/checkforupdates", $boardId, $version);
    return $self->get($board);
}

=method getCard

Get specific card for board

=cut

sub getCard {
    my ($self, $boardId, $cardId) = @_;
    my $board = sprintf("board/%s/getcard/%s", $boardId, $cardId);
    return $self->get($board);
}

=method getCardByExternalId

Get specific card for board by an external id

=cut

sub getCardByExternalId {
    my ($self, $boardId, $externalCardId) = @_;
    my $board = sprintf("board/%s/getcardbyexternalid/%s",
        $boardId, uri_escape($externalCardId));
    return $self->get($board);
}


=method addCard

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

=method addCards

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


=method moveCard

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


=method moveCardByExternalId

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


=method moveCardToBoard

Moves card to another board

=cut

sub moveCardToBoard {
    my ($self, $cardId, $destinationBoardId) = @_;
    my $moveCard = sprintf('card/movecardtoanotherboard/%s/%s',
        $cardId, $destinationBoardId);
    my $params = {};
    return $self->post($moveCard, $params);
}


=method updateCard

Update a card

=cut

sub updateCard {
    my ($self, $boardId, $card) = @_;
    $card->{UserWipOverrideComment} = $self->defaultWipOverrideReason;
    my $updateCard = sprintf('board/%s/UpdateCardWithWipOverride');
    return $self->post($updateCard, $card);
}

=method updateCardFields

Update fields in card

=cut
sub updateCardFields {
  my ($self, $updateFields) = @_;
  return $self->post('card/update', $updateFields);
}

=method getComments

Get comments for card

=cut
sub getComments {
  my ($self, $boardId, $cardId) = @_;
  my $comment = sprintf('card/getcomments/%s/%s', $boardId, $cardId);
  return $self->get($comment);
}

=method addComment

Add comment for card

=cut
sub addComment {
    my ($self, $boardId, $cardId, $userId, $comment) = @_;
    my $params = {PostedById => $userId, Text => $comment};
    my $addComment = sprintf('card/savecomment/%s/%s', $boardId, $cardId);
    return $self->post($addComment, $params);
}

=method addCommentByExternalId

Add comment for card

=cut

sub addCommentByExternalId {
    my ($self, $boardId, $externalCardId, $userId, $comment) = @_;
    my $params = {PostedById => $userId, Text => $comment};
    my $addComment = sprintf('card/savecommentbyexternalid/%s/%s',
        $boardId, uri_escape($externalCardId));
    return $self->post($addComment, $params);
}

=method getCardHistory

Get card history

=cut
sub getCardHistory {
  my ($self, $boardId, $cardId) = @_;
  my $history = sprintf('card/history/%s/%s', $boardId, $cardId);
  return $self->get($history);
}


=method searchCards

Search cards, options is a hashref of search options

Eg,

    searchOptions = {
        IncludeArchiveOnly: false,
        IncludeBacklogOnly: false,
        IncludeComments: false,
        IncludeDescription: false,
        IncludeExternalId: false,
        IncludeTags: false,
        AddedAfter: null,
        AddedBefore: null,
        CardTypeIds: [],
        ClassOfServiceIds: [],
        Page: 1,
        MaxResults: 20,
        OrderBy: "CreatedOn",
        SortOrder: 0
    };
=cut

sub searchCards {
    my ($self, $boardId, $options) = @_;
    my $search = sprintf('board/%s/searchcards', $boardId);
    return $self->post($search, $options);
}

=method getNewCards

Get latest added cards

=cut
sub getNewCards {
    my ($self, $boardId) = @_;
    my $newCards = sprintf('board/%s/listnewcards', $boardId);
    return $self->get($newCards);
}

=method deleteCard

Delete a single card

=cut
sub deleteCard {
    my ($self, $boardId, $cardId) = @_;
    my $delCard = sprintf('board/%s/deletecard/%s', $boardId, $cardId);
    return $self->post($delCard, {});
}

=method deleteCards

Delete batch of cards

=cut
sub deleteCards {
    my ($self, $boardId, $cardIds) = @_;
    my $delCard = sprintf('board/%s/deletecards', $boardId);
    return $self->post($delCard, $cardIds);
}

=method getTaskBoard

Get task board

=cut
sub getTaskBoard {
    my ($self, $boardId, $cardId) = @_;
    my $taskBoard =
      sprintf('v1/board/%s/card/%s/taskboard', $boardId, $cardId);
    return $self->get($taskBoard);
}

=method addTask

Adds task to card

=cut
sub addTask {
    my ($self, $boardId, $cardId, $taskCard) = @_;
    $taskCard->{UserWipOverrideComment} = $self->defaultWipOverrideReason;
    my $url = sprintf('v1/board/%s/card/%s/tasks/lane/%s/position/%s',
        $boardId, $cardId, $taskCard->{LaneId}, $taskCard->{Index});
    return $self->post($url, $taskCard);
}

=method updateTask

Updates task in card

=cut
sub updateTask {
    my ($self, $boardId, $cardId, $taskCard) = @_;
    $taskCard->{UserWipOverrideComment} = $self->defaultWipOverrideReason;
    my $url = sprintf('v1/board/%s/update/card/%s/tasks/%s',
        $boardId, $cardId, $taskCard->{Id});
    return $self->post($url, $taskCard);
}

=method deleteTask

Deletes task

=cut
sub deleteTask {
    my ($self, $boardId, $cardId, $taskId) = @_;
    my $url = sprintf('v1/board/%s/delete/card/%s/tasks/%s',
        $boardId, $cardId, $taskId);
    return $self->post($url, {});
}

=method getTaskBoardUpdates

Get latest task additions/changes

=cut
sub getTaskBoardUpdates {
    my ($self, $boardId, $cardId, $version) = @_;
    my $url = sprintf('v1/board/%s/card/%s/tasks/boardversion/%s',
        $boardId, $cardId, $version);
    return $self->get($url);
}

=method moveTask

Moves task to different lanes

=cut
sub moveTask {
    my ($self, $boardId, $cardId, $taskId, $toLaneId, $position) = @_;
    my $url = sprintf('v1/board/%s/move/card/%s/tasks/%s/lane/%s/position/%s',
        $boardId, $cardId, $taskId, $toLaneId, $position);
    return $self->post($url, {});
}

=method getAttachmentCount

Get num of attachments for card

=cut
sub getAttachmentCount {
  my ($self, $boardId, $cardId) = @_;
  my $url = sprintf('card/GetAttachmentsCount/%s/%s', $boardId, $cardId);
  return $self->get($url);
}

=method getAttachments

Get list of attachments

=cut
sub getAttachments {
  my ($self, $boardId, $cardId) = @_;
  my $url = sprintf('card/GetAttachments/%s/%s', $boardId, $cardId);
  return $self->get($url);
}

=method getAttachment

Get single attachment

=cut
sub getAttachment {
  my ($self, $boardId, $cardId, $attachmentId) = @_;
  my $url = sprintf('card/GetAttachments/%s/%s/%s', $boardId, $cardId, $attachmentId);
  return $self->get($url);
}

sub downloadAttachment {
  my $self = shift;
  return 'Not implemented';
}

=method deleteAttachment

Removes attachment from card

=cut
sub deleteAttachment {
  my ($self, $boardId, $cardId, $attachmentId) = @_;
  my $url = sprintf('card/DeleteAttachment/%s/%s/%s', $boardId, $cardId, $attachmentId);
  return $self->post($url, {});
}

sub addAttachment {
  my $self = shift;
  return 'Not Implemented';
}

1;

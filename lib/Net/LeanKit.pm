package Net::LeanKit;

# ABSTRACT: A perl library for Leankit.com

use strict;
use warnings;
use Carp qw(croak);
use Path::Tiny;
use HTTP::Tiny;
use JSON::Any;
use URI::Escape;
use Method::Signatures;
use Types::Standard qw( Str ArrayRef );
use Moo;
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

has email => (is => 'ro', isa => Str, required => 1);
has password => (is => 'ro', required => 1, isa => Str);
has account  => (is => 'ro', required => 1, isa => Str);
has boardIdentifiers => (is => 'rw', default => sub { +{} });
has defaultWipOverrideReason => (
    is      => 'ro',
    default => sub {'WIP Override performed by external system'}
);
has headers => (
    is      => 'ro',
    default => sub {
        {   'Accept'       => 'application/json',
            'Content-type' => 'application/json'
        };
    }
);

has ua => (is => 'ro', default => sub { HTTP::Tiny->new });
has j  => (is => 'ro', default => sub { JSON::Any->new });


=method get

GET requests to leankit

=cut

method get ($endpoint) {
    my $auth = uri_escape(sprintf("%s:%s", $self->email, $self->password));
    my $url = sprintf('https://%s@%s.leankit.com/kanban/api/%s',
        $auth, $self->account, $endpoint);

    my $r = $self->ua->get($url, {headers => $self->headers});
    croak "$r->{status} $r->{reason}" unless $r->{success};
    my $content = $r->{content} ? $self->j->decode($r->{content}) : +[];
    return $content->{ReplyData}->[0];
}

=method post

POST requests to leankit

=cut

method post ($endpoint, $body) {
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
    my $content = $r->{content} ? $self->j->decode($r->{content}) : +[];
    return $content->{ReplyData}->[0];
}


=method getBoards

Returns list of boards

=cut

method getBoards {
    return $self->get('boards');
}


=method getNewBoards

Returns list of latest created boards

=cut

method getNewBoards {
    return $self->get('ListNewBoards');
}

=method getBoard

Gets leankit board by id

=cut

method getBoard ($id) {
    my $boardId = sprintf('boards/%s', $id);
    return $self->get($boardId);
}


=method getBoardByName

Finds a board by name

=cut

method getBoardByName ($boardName) {
    foreach my $board (@{$self->getBoards}) {
        next unless $board->{Title} =~ /$boardName/i;
        return $board;
    }
}

=method getBoardIdentifiers

Get board identifiers

=cut

method getBoardIdentifiers ($boardId) {

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

method getBoardBacklogLanes ($boardId) {
    my $board = sprintf("board/%s/backlog", $boardId);
    return $self->get($board);
}

=method getBoardArchiveLanes

Get board archive lanes

=cut

method getBoardArchiveLanes ($boardId) {
    my $board = sprintf("board/%s/archive", $boardId);
    return $self->get($board);
}

=method getBoardArchiveCards

Get board archive cards

=cut

method getBoardArchiveCards ($boardId) {
    my $board = sprintf("board/%s/archivecards", $boardId);
    return $self->get($board);
}

=method getNewerIfExists

Get newer board version if exists

=cut

method getNewerIfExists ($boardId, $version) {
    my $board = sprintf("board/%s/boardversion/%s/getnewerifexists", $boardId,
        $version);
    return $self->get($board);
}

=method getBoardHistorySince

Get newer board history

=cut

method getBoardHistorySince ($boardId, $version) {
    my $board = sprintf("board/%s/boardversion/%s/getboardhistorysince",
        $boardId, $version);
    return $self->get($board);
}

=method getBoardUpdates

Get board updates

=cut

method getBoardUpdates ($boardId, $version) {
    my $board =
      sprintf("board/%s/boardversion/%s/checkforupdates", $boardId, $version);
    return $self->get($board);
}

=method getCard

Get specific card for board

=cut

method getCard ($boardId, $cardId) {
    my $board = sprintf("board/%s/getcard/%s", $boardId, $cardId);
    return $self->get($board);
}

=method getCardByExternalId

Get specific card for board by an external id

=cut

method getCardByExternalId ($boardId, $externalCardId) {
    my $board = sprintf("board/%s/getcardbyexternalid/%s",
        $boardId, uri_escape($externalCardId));
    return $self->get($board);
}


=method addCard

Add a card to the board/lane specified. The card hash usually contains

  { TypeId => 1,
    Title => 'my card title',
    ExternalCardId => DATETIME,
    Priority => 1
  }

=cut

method addCard ($boardId, $laneId, $position, $card) {
    $card->{UserWipOverrideComment} = $self->defaultWipOverrideReason;
    my $newCard =
      sprintf('board/%s/AddCardWithWipOverride/Lane/%s/Position/%s',
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

method addCards ($boardId, ArrayRef $cards) {
    my $newCard = sprintf('board/%s/AddCards?wipOverrideComment="%s"',
        $boardId, $self->defaultWipOverrideReason);
    return $self->post($newCard, $cards);
}


=method moveCard

Moves card to different lanes

=cut

method moveCard ($boardId, $cardId, $toLaneId, $position) {
    my $moveCard =
      sprintf('board/%s/movecardwithwipoverride/%s/lane/%s/position/%s',
        $boardId, $cardId, $toLaneId, $position);
    my $params = {comment => $self->defaultWipOverrideReason};
    return $self->post($moveCard, $params);
}


=method moveCardByExternalId

Moves card to different lanes by externalId

=cut

method moveCardByExternalId ($boardId, $externalCardId, $toLaneId, $position) {
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

method moveCardToBoard ($cardId, $destinationBoardId) {
    my $moveCard = sprintf('card/movecardtoanotherboard/%s/%s',
        $cardId, $destinationBoardId);
    my $params = {};
    return $self->post($moveCard, $params);
}


=method updateCard

Update a card

=cut

method updateCard ($boardId, $card) {
    $card->{UserWipOverrideComment} = $self->defaultWipOverrideReason;
    my $updateCard = sprintf('board/%s/UpdateCardWithWipOverride');
    return $self->post($updateCard, $card);
}

=method updateCardFields

Update fields in card

=cut

method updateCardFields ($updateFields) {
    return $self->post('card/update', $updateFields);
}

=method getComments

Get comments for card

=cut

method getComments ($boardId, $cardId) {
    my $comment = sprintf('card/getcomments/%s/%s', $boardId, $cardId);
    return $self->get($comment);
}

=method addComment

Add comment for card

=cut

method addComment ($boardId, $cardId, $userId, $comment) {
    my $params = {PostedById => $userId, Text => $comment};
    my $addComment = sprintf('card/savecomment/%s/%s', $boardId, $cardId);
    return $self->post($addComment, $params);
}

=method addCommentByExternalId

Add comment for card

=cut

method addCommentByExternalId ($boardId, $externalCardId, $userId, $comment) {
    my $params = {PostedById => $userId, Text => $comment};
    my $addComment = sprintf('card/savecommentbyexternalid/%s/%s',
        $boardId, uri_escape($externalCardId));
    return $self->post($addComment, $params);
}

=method getCardHistory

Get card history

=cut

method getCardHistory ($boardId, $cardId) {
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

method searchCards ($boardId, $options) {
    my $search = sprintf('board/%s/searchcards', $boardId);
    return $self->post($search, $options);
}

=method getNewCards

Get latest added cards

=cut

method getNewCards ($boardId) {
    my $newCards = sprintf('board/%s/listnewcards', $boardId);
    return $self->get($newCards);
}

=method deleteCard

Delete a single card

=cut

method deleteCard ($boardId, $cardId) {
    my $delCard = sprintf('board/%s/deletecard/%s', $boardId, $cardId);
    return $self->post($delCard, {});
}

=method deleteCards

Delete batch of cards

=cut

method deleteCards ($boardId, $cardIds) {
    my $delCard = sprintf('board/%s/deletecards', $boardId);
    return $self->post($delCard, $cardIds);
}

=method getTaskBoard

Get task board

=cut

method getTaskBoard ($boardId, $cardId) {
    my $taskBoard =
      sprintf('v1/board/%s/card/%s/taskboard', $boardId, $cardId);
    return $self->get($taskBoard);
}

=method addTask

Adds task to card

=cut

method addTask ($boardId, $cardId, $taskCard) {
    $taskCard->{UserWipOverrideComment} = $self->defaultWipOverrideReason;
    my $url = sprintf('v1/board/%s/card/%s/tasks/lane/%s/position/%s',
        $boardId, $cardId, $taskCard->{LaneId}, $taskCard->{Index});
    return $self->post($url, $taskCard);
}

=method updateTask

Updates task in card

=cut

method updateTask ($boardId, $cardId, $taskCard) {
    $taskCard->{UserWipOverrideComment} = $self->defaultWipOverrideReason;
    my $url = sprintf('v1/board/%s/update/card/%s/tasks/%s',
        $boardId, $cardId, $taskCard->{Id});
    return $self->post($url, $taskCard);
}

=method deleteTask

Deletes task

=cut

method deleteTask ($boardId, $cardId, $taskId) {
    my $url = sprintf('v1/board/%s/delete/card/%s/tasks/%s',
        $boardId, $cardId, $taskId);
    return $self->post($url, {});
}

=method getTaskBoardUpdates

Get latest task additions/changes

=cut

method getTaskBoardUpdates ($boardId, $cardId, $version) {
    my $url = sprintf('v1/board/%s/card/%s/tasks/boardversion/%s',
        $boardId, $cardId, $version);
    return $self->get($url);
}

=method moveTask

Moves task to different lanes

=cut

method moveTask ($boardId, $cardId, $taskId, $toLaneId, $position) {
    my $url = sprintf('v1/board/%s/move/card/%s/tasks/%s/lane/%s/position/%s',
        $boardId, $cardId, $taskId, $toLaneId, $position);
    return $self->post($url, {});
}

=method getAttachmentCount

Get num of attachments for card

=cut

method getAttachmentCount ($boardId, $cardId) {
    my $url = sprintf('card/GetAttachmentsCount/%s/%s', $boardId, $cardId);
    return $self->get($url);
}

=method getAttachments

Get list of attachments

=cut

method getAttachments ($boardId, $cardId) {
    my $url = sprintf('card/GetAttachments/%s/%s', $boardId, $cardId);
    return $self->get($url);
}

=method getAttachment

Get single attachment

=cut

method getAttachment ($boardId, $cardId, $attachmentId) {
    my $url = sprintf('card/GetAttachments/%s/%s/%s',
        $boardId, $cardId, $attachmentId);
    return $self->get($url);
}

method downloadAttachment ($boardId, $cardId, $attachmentId, $dst) {
    my $url = sprintf('card/DownloadAttachment/%s/%s/%s',
        $boardId, $cardId, $attachmentId);
    my $dl = $self->get($url);
    path($dst)->spew($dl);
}


=method deleteAttachment

Removes attachment from card

=cut

method deleteAttachment ($boardId, $cardId, $attachmentId) {
    my $url = sprintf('card/DeleteAttachment/%s/%s/%s',
        $boardId, $cardId, $attachmentId);
    return $self->post($url, {});
}

# method addAttachment($boardId, $cardId, $description, $file) {
#   my $url = sprintf('card/SaveAttachment/%s/%s', $boardId, $cardId);
#   my $filename = path($file);
#   my $attachment_data = { Id => 0, Description => $description, FileName => $filename->basename};
#   return $self->post($url, $file, $attachment_data);
# }

1;

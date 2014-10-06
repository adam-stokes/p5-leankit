package Net::LeanKit;

# ABSTRACT: A perl library for Leankit.com

use strict;
use warnings;
use Carp;
use HTTP::Tiny;
use JSON::Any;
use URI::Escape;
use namespace::clean;

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
      sub {'WIP Override performed by external system'}
};

sub BUILD {
    my ($self, $args) = @_;
    for my $req (qw/ email password account/) {
        croak "$req attribute required" unless defined $self->$req;
    }
}

=method client

Builds client url and sets up authentication with api service

=cut

sub client {
    my ($self, $method, $endpoint) = @_;
    my $auth = uri_escape(sprintf("%s:%s", $self->email, $self->password));
    my $url = sprintf('https://%s@%s.leankit.com/kanban/api/%s',
        $auth, $self->account, $endpoint);
    my $http  = HTTP::Tiny->new;
    my $j     = JSON::Any->new;
    my $res   = $http->request(uc $method, $url);
    my $j_res = $j->decode($res->{content});
    if ($j_res->{ReplyCode} == 200) {
        return $j_res->{ReplyData}->[0];
    }
    return +[];
}


=method getBoards

Returns list of boards

=cut

sub getBoards {
    my ($self) = @_;
    my $res = $self->client('GET', 'boards');
    return $res;
}


=method getNewBoards

Returns list of latest created boards

=cut

sub getNewBoards {
    my ($self) = @_;
    return $self->client('GET', 'ListNewBoards');
}

=method getBoard(INT id)

Gets leankit board by id

=cut

sub getBoard {
    my ($self, $id) = @_;
    my $boardId = sprintf('boards/%s', $id);
    return $self->client('GET', $boardId);
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
    my $data = $self->client('GET', $board);
    $self->boardIdentifiers->{$boardId} = $data;
    return $self->boardIdentifiers->{$boardId};
}

=method getBoardBacklogLanes(INT boardId)

Get board back log lanes

=cut

sub getBoardBacklogLanes {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/backlog", $boardId);
    return $self->client('GET', $board);
}

=method getBoardArchiveLanes(INT boardId)

Get board archive lanes

=cut

sub getBoardArchiveLanes {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/archive", $boardId);
    return $self->client('GET', $board);
}

=method getBoardArchiveCards(INT boardId)

Get board archive cards

=cut

sub getBoardArchiveCards {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/archivecards", $boardId);
    return $self->client('GET', $board);
}

=method getNewerIfExists(INT boardId, INT version)

Get newer board version if exists

=cut

sub getNewerIfExists {
    my ($self, $boardId, $version) = @_;
    my $board = sprintf("board/%s/boardversion/%s/getnewerifexists", $boardId,
        $version);
    return $self->client('GET', $board);
}

=method getBoardHistorySince(INT boardId, INT version)

Get newer board history

=cut

sub getBoardHistorySince {
    my ($self, $boardId, $version) = @_;
    my $board = sprintf("board/%s/boardversion/%s/getboardhistorysince",
        $boardId, $version);
    return $self->client('GET', $board);
}

=method getBoardUpdates(INT boardId, INT version)

Get board updates

=cut

sub getBoardUpdates {
    my ($self, $boardId, $version) = @_;
    my $board =
      sprintf("board/%s/boardversion/%s/checkforupdates", $boardId, $version);
    return $self->client('GET', $board);
}

=method getCard(INT boardId, INT cardId)

Get specific card for board

=cut

sub getCard {
    my ($self, $boardId, $cardId) = @_;
    my $board = sprintf("board/%s/getcard/%s", $boardId, $cardId);
    return $self->client('GET', $board);
}

=method getCardByExternalId(INT boardId, INT cardId)

Get specific card for board by an external id

=cut

sub getCardByExternalId {
    my ($self, $boardId, $externalCardId) = @_;
    my $board = sprintf("board/%s/getcardbyexternalid/%s",
        $boardId, uri_escape($externalCardId));
    return $self->client('GET', $board);
}

1;

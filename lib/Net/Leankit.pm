package Net::Leankit;

# ABSTRACT: Net::Leankit is a perl library for Leankit.com

use strict;
use warnings;
use Carp;
use HTTP::Tiny;
use JSON::Any;

=attr username

Username, which is your email.

=attr password

Password

=attr account

Account name in which your account is under, usually a company name.

=cut

use Class::Tiny qw( username password account );

sub BUILD {
    my ($self, $args) = @_;
    for my $req (qw/ username password account/) {
        croak "$req attribute required" unless defined $self->$req;
    }
}

=method client

Builds client url and sets up authentication with api service

=cut

sub client {
    my ($self, $method, $endpoint) = @_;
    my $url = sprintf('https://%s:%s@%s.leankit.com/kanban/api/%s',
        $self->username, $self->password, $self->account, $endpoint);
    my $http = HTTP::Tiny->new;
    my $j    = JSON::Any->new;
    my $res  = $http->request(uc $method, $url);
    if (length $res->{content}) {
        return $j->decode($res->{content});
    }
    return +{};
}


=method getBoards

Returns list of boards

=cut

sub getBoards {
    my ($self) = @_;
    return $self->client('GET', 'boards');
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
        if (defined $board && length $board) {
            if ($board->{title} =~ /$boardName/) {
                return $self->getBoard($board->{Id});
            }
        }
    }
    return +{};
}

1;

package Net::LeanKit;

# ABSTRACT: Net::LeanKit is a perl library for Leankit.com

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

use Class::Tiny qw( email password account );

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
    my $http = HTTP::Tiny->new;
    my $j    = JSON::Any->new;
    my $res  = $http->request(uc $method, $url);
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

1;

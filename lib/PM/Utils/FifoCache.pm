package PM::Utils::FifoCache;
use strict;
use warnings;
use Carp qw/confess/;

sub new {
    my ($class, %args) = @_;
    confess(
        'please provide size => '.
        '[ integer size of fifo queue ]'
    ) unless (
        $args{'size'} && $args{'size'} =~ /^\d+$/
    );

    return bless({
        'size'      => $args{'size'},
        '_queue'    => [(undef) x $args{'size'}],
        '_tail'     => 0,
    }, $class);
}

sub add {
    my ($self, $value) = @_;
    $self->{'_queue'}[$self->{'_tail'}] = $value;
    $self->{'_tail'} =
        $self->{'_tail'} == ($self->{'size'} - 1) ?
        0 : ($self->{'_tail'} + 1);
}

sub get_all {
    my ($self) = @_;
    my $res = [];
    my $hand = $self->{'_tail'};
    for (1 .. $self->{'size'}) {
        if (defined $self->{'_queue'}[$hand]) {
            push(@$res, $self->{'_queue'}[$hand]);
        }
        $hand = $hand == ($self->{'size'} - 1) ?
            0 : ($hand + 1);
    }
    return $res;
}

1;

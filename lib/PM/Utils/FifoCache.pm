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
        '_is_empty' => 1,
    }, $class);
}

sub add {
    my ($self, $value) = @_;
    $self->{'_queue'}[$self->{'_tail'}] = $value;
    $self->{'_is_empty'} = 0;
    $self->{'_tail'} =
        $self->{'_tail'} == ($self->{'size'} - 1) ?
        0 : ($self->{'_tail'} + 1);
}

sub is_empty {
    my ($self) = @_;
    return $self->{'_is_empty'};
}

sub most_recent_entry {
    my ($self) = @_;
    return $self->{'_queue'}[$self->{'_tail'} - 1];
}

sub iterate_entries {
    my ($self, $continue_cb) = @_;
    confess(
        'please provide continue callback as the first argument'
    ) unless (ref($continue_cb) eq 'CODE');
    my $hand = $self->{'_tail'} - 1;
    for (1 .. $self->{'size'}) {
        last unless (
            $continue_cb->($self->{'_queue'}[$hand])
        );
        $hand--;
    }
}

sub clear {
    my ($self) = @_;
    @{ $self->{'_queue'} } = (undef) x $self->{'size'};
    $self->{'_is_empty'} = 1;
}

1;

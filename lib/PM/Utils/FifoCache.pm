package PM::Utils::FifoCache;
use strict;
use warnings;
use Carp qw/confess/;
use PM::Utils qw/is_int/;

#
#   Description
#
#   A simple implementation of FIFO queue
#   based on a simple array
#

sub new {
    my ($class, %args) = @_;
    confess(
        'please provide size => '.
        '[ integer size of fifo queue ]'
    ) unless (is_int($args{'size'}));

    return bless({
        'size'      => $args{'size'},

        # preventively creating array of a given size
        '_queue'    => [(undef) x $args{'size'}],

        # a pointer to the tail element
        # when new element comes it is placed at a _tail
        # position then _tail is incremented by one
        # or wrapped around
        '_tail'     => 0,
        '_is_empty' => 1,
    }, $class);
}

# adds new value given as the first argument
# returns a replaced value or undef if none replaced
# actually the value argument is not required
# to be defined so it's the caller-side turn
# to decide how to deal with returned value
sub add {
    my ($self, $value) = @_;
    my $replaced_value = $self->{'_queue'}[$self->{'_tail'}];
    $self->{'_queue'}[$self->{'_tail'}] = $value;
    $self->{'_is_empty'} = 0;
    $self->{'_tail'} =
        $self->{'_tail'} == ($self->{'size'} - 1) ?
        0 : ($self->{'_tail'} + 1);
    return $replaced_value;
}

# just an accessor method
sub is_empty {
    my ($self) = @_;
    return $self->{'_is_empty'};
}

# returns value that was added most recently
# aka head value
sub most_recent_entry {
    my ($self) = @_;
    return $self->{'_queue'}[$self->{'_tail'} - 1];
}

# iterates values in reversed order contrariwise as
# they come starting from the most recent one
# requires a callback function as the first argument
# that will be called on each iteration and will be given
# a current value as a single argument
# this way we may retrive a portion of cached values
# using a closure technique
# if callback function returns true value loop continues
# or otherwise breaks
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

# sometimes we really want to forget everything
sub clear {
    my ($self) = @_;
    @{ $self->{'_queue'} } = (undef) x $self->{'size'};
    $self->{'_is_empty'} = 1;
}

1;

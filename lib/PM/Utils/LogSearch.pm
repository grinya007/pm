package PM::Utils::LogSearch;
use strict;
use warnings;
use Carp qw/confess/;
use Fcntl qw/SEEK_SET/;

#
#   Description
#
#   Efficient searcher that implements Fibonacci search
#   technique over log file leaning on assumption that
#   log entries must have been written in strict
#   timestamp ascending order. Yet it's absolutely normal
#   to have non-unique timestamps in the log.
#   The comparison itself isn't implemented here hence it's the
#   caller-side turn to decide how to parse and compare
#   timestamps.
#
#   In example, it produces not more than 40 seek calls
#   and reads not more than 5 Kb while searching for
#   any timestamp over a 10 Mb log file
#   (I took zypper.log for testing (not a zypp/history)
#   which keeps a relatively uniform lines in log ~100 bytes each
#   and also has timestamp on each line)
#

# obviously constructor
# a self-documented guy
sub new {
    my ($class, %args) = @_;
    confess(
        'please provide log => '.
        '[ an opened log file handle blessed with IO::File ]'
    ) if (
        ref($args{'log'}) ne 'IO::File' ||
        !$args{'log'}->opened()
    );
    confess(
        'please provide cmp => '.
        '[ callback function that compares ts against the line ]'
    ) if (
        ref($args{'cmp'}) ne 'CODE'
    );
    return bless({
        'log' => $args{'log'},
        'cmp' => $args{'cmp'},
    }, $class);
}

sub locate {
    my ($self, $ts) = @_;
    confess(
        'please provide sought-for timestamp in a '.
        'log file specific format as first argument'
    ) unless (defined $ts);
    my $size = ($self->{'log'}->stat())[7];

    # starting from these Fibonacci numbers because
    # a single line in an average log file will
    # hardly keep less than 100 bytes hence it makes
    # sense to skip lesser search iterations
    # in most cases
    my @fib = (144, 233);
    while ((my $f = $fib[-2] + $fib[-1]) < $size) {
        push(@fib, $f);
    }

    # here we go
    #   $k - keeps index of current Fibonacci number
    #        it (index) decreases by one on each iteration
    #   $i - keeps pointer in file from where we will
    #        start scanning in search of fortune
    #        to compare something against sought-for timestamp
    #   $p - will keep the last known position where we saw
    #        timestamp that was less than sought-for one
    my ($k, $i, $p) = ($#fib, $fib[-1], 0);
    while ($k > 0 && $i >= 0) {

        # will pull copmarison result
        # out of inner loop
        my $cmp;

        # seek
        $self->{'log'}->seek($i, SEEK_SET);
        # and -destroy- read
        # please refer to compare_cb() method description
        # given in lib/PM/Log.pm for details on how
        # it works
        while (!$self->{'log'}->eof()) {
            $cmp = $self->{'cmp'}->(
                $ts, $self->{'log'}->getline()
            );
            last if (defined $cmp);
        }

        if (defined($cmp) && $cmp > 0) {
            
            # the sought-for timestamp is greater than
            # one that we met on current iteration
            # remember position
            $p = $i;

            # calculate next value for $i (going down)
            my $ni = $fib[--$k] + $self->{'log'}->tell();

            # make sure that we are not going
            # beyond appearances
            $i = $ni < $size ? $ni : $size;
        }
        else {

            # the sought-for timestamp is less or equal than
            # the one that we have last seen or even we
            # possibly don't have a result of comparison,
            # going up, there is nothing to take from here,
            # note that outer loop will break in case we will
            # reach the beginning of the file
            $i -= $fib[--$k];
        }
    }

    # once $p is known lets do final
    # precise scan to find the particular position
    $self->{'log'}->seek($p, SEEK_SET);
    while (!$self->{'log'}->eof()) {
        $p = $self->{'log'}->tell();
        my $cmp = $self->{'cmp'}->(
            $ts, $self->{'log'}->getline()
        );

        # in case we've found the first timestamp in file
        # that is equal to sought-for one
        # or that is greater (which means that there is
        # no equal timestamp in file) we break the loop
        # and $p will point to it
        last if (defined($cmp) && $cmp <= 0);

        # setting $p to eof otherwise
        $p = $size;
    }

    # finally, the result of search is just
    # properly set pointer in the file (IO::File object)
    # that was provided to constructor
    $self->{'log'}->seek($p, SEEK_SET);
}


1;

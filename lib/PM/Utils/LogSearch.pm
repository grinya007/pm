package PM::Utils::LogSearch;
use strict;
use warnings;
use Carp qw/confess/;
use Fcntl qw/SEEK_SET/;
use PM::Utils qw/is_int/;

#
#   Description
#
#   Efficient searcher that implements Fibonacci search
#   technique over log file leaning on assumption that
#   log entries must have been written in strict
#   timestamp ascending order. Yet it's absolutely normal
#   to have non-unique timestamps in the log.
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
        'please parse_ts => '.
        '[ callback function that parses ts from given line ]'
    ) if (
        ref($args{'parse_ts'}) ne 'CODE'
    );
    return bless({
        'log'       => $args{'log'},
        'parse_ts'  => $args{'parse_ts'},
    }, $class);
}

sub locate {
    my ($self, $ts) = @_;
    confess(
        'please provide sought-for timestamp in a '.
        'unix epoch format'
    ) unless (is_int($ts));
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
    #        note that $fib[0] == 144
    #   $i - keeps pointer in file from where we will
    #        start scanning in search of fortune
    #        to compare something against sought-for timestamp
    #   $p - will keep the last known position where we saw
    #        timestamp that was less than sought-for one
    my ($k, $i, $p) = ($#fib, $fib[-1], 0);
    while ($k > 0 && $i >= 0) {

        # will pull timestamp parsing
        # result out of inner loop
        my $line_ts;

        # seek
        $self->{'log'}->seek($i, SEEK_SET);
        # and -destroy- read
        # please refer to parse_ts_cb() method description
        # given in lib/PM/Log.pm for details on how
        # it ment to work
        while (!$self->{'log'}->eof()) {
            $line_ts = $self->{'parse_ts'}->(
                $self->{'log'}->getline()
            );
            last if (defined($line_ts));
        }
        confess(
            'bad return value from parse_ts callback'
        ) if (defined($line_ts) && !is_int($line_ts));

        if (defined($line_ts) && $line_ts < $ts) {
            
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
            # currently don't have any comparable timestamp,
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
        my $line_ts = $self->{'parse_ts'}->(
            $self->{'log'}->getline()
        );

        # in case we've found the first timestamp in file
        # that is equal to sought-for one
        # or that is greater (which means that there is
        # no equal timestamp in file) we break the loop
        # and $p will point to it
        last if (defined($line_ts) && $line_ts >= $ts);

        # setting $p to eof otherwise
        $p = $size;
    }

    # finally, the result of search is just
    # properly set pointer in the file (IO::File object)
    # that was provided to constructor
    $self->{'log'}->seek($p, SEEK_SET);
}


1;

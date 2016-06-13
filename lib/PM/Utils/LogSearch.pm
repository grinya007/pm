package PM::Utils::LogSearch;
use strict;
use warnings;
use Carp qw/confess/;
use Fcntl qw/SEEK_SET/;

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
    my @fib = (144, 233);
    while ((my $f = $fib[-2] + $fib[-1]) < $size) {
        push(@fib, $f);
    }
    my ($k, $i, $p) = ($#fib, $fib[-1], 0);
    while ($k > 0 && $i >= 0) {
        my $cmp;
        $self->{'log'}->seek($i, SEEK_SET);
        while (!$self->{'log'}->eof()) {
            $cmp = $self->{'cmp'}->(
                $ts, $self->{'log'}->getline()
            );
            last if (defined $cmp);
        }
        if (defined($cmp) && $cmp > 0) {
            $p = $i;
            my $ni = $fib[--$k] + $self->{'log'}->tell();
            $i = $ni < $size ? $ni : $size;
        }
        else {
            $i -= $fib[--$k];
        }
    }
    $self->{'log'}->seek($p, SEEK_SET);
    while (!$self->{'log'}->eof()) {
        $p = $self->{'log'}->tell();
        my $cmp = $self->{'cmp'}->(
            $ts, $self->{'log'}->getline()
        );
        last if (defined($cmp) && $cmp <= 0);
        $p = $size;
    }
    $self->{'log'}->seek($p, SEEK_SET);
}


1;

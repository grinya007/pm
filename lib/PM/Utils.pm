package PM::Utils;
use strict;
use warnings;

use Carp qw/confess/;
use POSIX qw/strftime/;
use Time::Local;

use base 'Exporter';
our @EXPORT = qw//; 
our @EXPORT_OK = qw/
    is_int
/;
our %EXPORT_TAGS = (
    TIME    => [qw/
        is_valid_ts
        unix_to_ts
        ts_to_unix
    /],
);
{
    my %export;
    @export{ map { @$_ } values %EXPORT_TAGS } = ();
    push @EXPORT_OK, keys %export;
}

# efficient test of value to be integer
# performs twice as faster than $i =~ /^\d+$/
sub is_int {
    my ($int) = @_;
    return undef unless (defined($int));
    no warnings 'numeric';
    return undef unless ($int eq int($int));
    return 1;
}

# :TIME utils
use constant 'TSRE' => 
    qr/^(\d{4})-(\d{2})-(\d{2})(?: (\d{2}):(\d{2}):(\d{2})(?:(\.\d{1,9}))?)?$/;

# YYYY-mm-dd HH:MM:SS timestamp validation
sub is_valid_ts {
    my ($ts) = @_;
    return undef unless ($ts);
    return undef unless ($ts =~ TSRE());
    return eval {
        timelocal(($6||0)+0, ($5||0)+0, ($4||0)+0, $3+0, $2-1, $1+0)
    };
}

# NOTE:
#   both ts_to_unix() and unix_to_ts()
#   are built on top of timelocal() and localtime()
#   respectively hence the YYYY-mm-dd HH:MM:SS timestamp
#   will have timezone offset and the unix epoch timestamp
#   will not

# YYYY-mm-dd HH:MM:SS timestamp conversion
# to unix epoch timestamp
sub ts_to_unix {
    my ($ts) = @_;
    my $unix = is_valid_ts($ts);
    confess(
        'ts is invalid'.($@ ? ': '.$@ : '')
    ) unless (defined($unix));
    return $unix;
}

# vice versa
sub unix_to_ts {
    my ($unix) = @_;
    confess('bad unix ts') unless (is_int($unix));
    return strftime('%F %T', localtime($unix));
}


1;

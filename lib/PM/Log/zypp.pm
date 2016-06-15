package PM::Log::zypp;
use base 'PM::Log';
use strict;
use warnings;
use feature qw/state/;
use Carp qw/confess/;
use PM::Utils qw/is_int/;
use POSIX qw/strftime/;

use constant 'TSRE' => qr/^(\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d)\|/;

sub format_ts {
    my ($class, $ts) = @_;
    confess('bad ts arg') unless (
        is_int($ts)
    );
    return strftime('%F %T', localtime($ts));
}

sub compare_cb  {
    my ($class) = @_;
    state $cb = sub {
        my ($ts, $line) = @_;
        my ($line_ts) = $line =~ TSRE;
        return undef unless (defined $line_ts);
        return $ts cmp $line_ts;
    };
    return $cb;
}

package PM::Log::zypp::Entry;
use base 'PM::Log::Entry';
use strict;
use warnings;
use Carp qw/confess/;
use Digest::MD5 qw/md5_hex/;

sub load_from_line {
    my ($class, $line) = @_;
    return undef unless ($line =~ PM::Log::zypp::TSRE);
    my ($ts, $action, $package, $version, $arch) = split /\s*\|\s*/, $line;
    return undef unless ($action);
    return undef unless (grep { $action eq $_ } qw/install remove/);
    return $class->new(
        'timestamp' => $ts,
        'action'    => $action,
        'package'   => $package,
        'version'   => $version,
        'arch'      => $arch,
        'hash'      => md5_hex(
            join('$$', $ts, $action, $package, $version, $arch)
        ),
    );
}

1;

package PM::Log::dummy;
use base 'PM::Log';
use strict;
use warnings;
use feature qw/state/;

#
#   Description
#
#   The dummy driver module created for diversity
#   of examples. It is also used for testing purposes.
#

use constant 'TSRE' => qr/^(\d+)\|/;

sub parse_ts_cb  {
    my ($class) = @_;
    state $cb = sub {
        my ($line) = @_;
        my ($line_ts) = $line =~ TSRE;
        return undef unless (defined $line_ts);
        return $line_ts;
    };
    return $cb;
}

package PM::Log::dummy::Entry;
use base 'PM::Log::Entry';
use strict;
use warnings;
use Carp qw/confess/;
use Digest::MD5 qw/md5_hex/;
use PM::Utils qw/:TIME/;

sub load_from_line {
    my ($class, $line) = @_;
    return undef unless ($line =~ PM::Log::dummy::TSRE);
    my ($ts, $action, $package, $version, $arch) = split /\s*\|\s*/, $line;
    return undef unless ($action);
    return undef unless (grep { $action eq $_ } qw/in rm/);
    state $action_dict = {'in' => 'install', 'rm' => 'remove'};
    $action = $action_dict->{$action};
    return $class->new(
        'timestamp' => unix_to_ts($ts),
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

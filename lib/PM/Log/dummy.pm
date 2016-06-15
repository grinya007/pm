package PM::Log::dummy;
use base 'PM::Log';
use strict;
use warnings;
use feature qw/state/;
use Carp qw/confess/;
use PM::Utils qw/is_int/;

use constant 'TSRE' => qr/^(\d+)\|/;

sub format_ts {
    my ($class, $ts) = @_;
    confess('bad ts arg') unless (
        is_int($ts)
    );
    return $ts;
}

sub compare_cb  {
    my ($class) = @_;
    state $cb = sub {
        my ($ts, $line) = @_;
        my ($line_ts) = $line =~ TSRE;
        return undef unless (defined $line_ts);
        return $ts <=> $line_ts;
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

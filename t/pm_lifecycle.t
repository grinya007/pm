use strict;
use Test::More;
use Test::MockTime qw/set_fixed_time/;
use POSIX qw/tzset/;

use FindBin qw/$RealBin/;
use lib "$RealBin/../lib";

BEGIN {
    $ENV{'PM_NAME'}         = 'dummy';
    $ENV{'PM_LOG'}          = __FILE__;
    $ENV{'PM_MAX_TIME'}     = 600;
    $ENV{'PM_MAX_ENTRIES'}  = 5;
    $ENV{'TZ'}              = 'Europe/London';
    tzset();
};

set_fixed_time(1234568888);

use_ok('PM', 'use PM;');

my $pm = PM->new('app_dir' => "$RealBin/..");

eval {
    my $pm = PM->new('app_dir' => "$RealBin/..");
};
ok(
    defined($@),
    'subsequent PM->new(...) call is prevented'
);

ok(
    PM->handle() == $pm,
    'PM->handle() keeps the right object'
);

ok(
    ref($pm->log_handle()) eq 'PM::Log::dummy',
    'proper driver taken'
);


my $entries = $pm->log_handle()->whats_up();

ok(
    scalar(@$entries) == 5,
    'took exactly 5 entries'
);

is_deeply(
    $entries->[0],
    {
        'timestamp' => '2009-02-13 23:44:10',
        'action'    => 'install',
        'package'   => 'lsscsi',
        'version'   => '0.27-4.1.2',
        'arch'      => 'x86_64',
        'hash'      => 'adf6bc4fcb0446dbcf941c7086022cee',
    },
    'the fifth most recent entry is in its place'
);

is_deeply(
    $entries->[-1],
    {
        'timestamp' => '2009-02-13 23:48:03',
        'action'    => 'install',
        'package'   => 'libx86emu1',
        'version'   => '1.1-22.1.2',
        'arch'      => 'x86_64',
        'hash'      => '4a6e0a3f205cabee2f9fe7733ce83529',
    },
    'the most recent entry is correct'
);

my $more_entries = $pm->log_handle()->whats_up(
    'after' => 'adf6bc4fcb0446dbcf941c7086022cee'
);

ok(
    scalar(@$more_entries) == 4,
    'took exactly 4 entries'
);

is_deeply(
    $more_entries->[0],
    {
        'timestamp' => '2009-02-13 23:45:06',
        'action'    => 'remove',
        'package'   => 'libz1',
        'version'   => '1.2.8-5.1.2',
        'arch'      => 'x86_64',
        'hash'      => 'f5b9c900b34f59e4c81024b957f66a3e',
    },
    'the fourth most recent entry in in its place'
);

is_deeply(
    $entries->[-1],
    $more_entries->[-1],
    'tails match'
);

done_testing();

__END__
1234568391|in|sysfsutils|2.1.0-152.1.2|x86_64
1234568406|in|prctl|1.6-2.1.2|x86_64
1234568418|in|pkg-config|0.28-7.1.2|x86_64
1234568552|in|perl-base|5.20.1-1.3|x86_64
1234568581|rm|net-tools|1.60-765.1.2|x86_64
1234568605|in|mozilla-nspr|4.10.7-1.2|x86_64
1234568650|in|lsscsi|0.27-4.1.2|x86_64
1234568706|rm|libz1|1.2.8-5.1.2|x86_64
1234568706|in|libyaml-0-2|0.1.6-2.1.2|x86_64
1234568706|in|libxtables10|1.4.21-3.1.2|x86_64
1234568883|in|libx86emu1|1.1-22.1.2|x86_64

package PM::Log;
use strict;
use warnings;
use Carp qw/confess/;

use IO::File;
use PM;
use PM::Utils qw/json_encode/;
use PM::Utils::FifoCache;
use PM::Utils::LogSearch;

sub new {
    my ($class) = @_;
    confess('this is abstract class') if (
        $class eq __PACKAGE__
    );
    my $self = bless({}, $class);
    $self->_init();
    return $self;
}

sub _init {
    my ($self) = @_;
    my $config = PM->handle()->config();
    my $cache = PM::Utils::FifoCache->new(
        'size'  => $config->get('pm_max_entries')
    );
    my $file = IO::File->new(
        '<' . $config->get('pm_log')
    );
    confess(
        'failed to open '.$config->get('pm_name').' log: '.$!
    ) unless ($file);
    my $searcher = PM::Utils::LogSearch->new(
        'log'   => $file,
        'cmp'   => $self->compare_cb(),
    );
    $searcher->locate(
        $self->format_ts(time() - $config->get('pm_max_time'))
    );
    my $entry_class = ref($self).'::Entry';
    while (!$file->eof()) {
        my $entry = $entry_class->load_from_line(
            $file->tell(), $file->getline()
        );
        next unless ($entry);
        $cache->add($entry);
    }
    $self->{'_cache'} = $cache;
    $file->close();
}

sub to_json {
    my ($self) = @_;
    my $entries = $self->{'_cache'}->get_all();
    @$entries = map { $_->to_hash() } @$entries;
    return json_encode($entries);
}

sub format_ts   { ... }
sub compare_cb  { ... }

package PM::Log::Entry;
use strict;
use warnings;
use Carp qw/confess/;

use constant 'ATTRS' => {
    'action'    => qr/^(?:install|remove)$/,
    'timestamp' => qr/^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$/,
    'package'   => qr/^[-+\.\~_a-zA-Z0-9]+$/,
    'version'   => qr/^[-+\.\~_a-zA-Z0-9]+$/,
    'arch'      => qr/^[-+\.\~_a-zA-Z0-9]+$/,
    'position'  => qr/^\d+$/,
};

sub new {
    my ($class, %args) = @_;
    confess('this is abstract class') if (
        $class eq __PACKAGE__
    );
    for my $attr (keys %{ ATTRS() }) {
        confess("$attr is required to be defined") unless (
            defined $args{$attr}
        );
        confess("bad $attr attribute value $args{$attr}") unless (
            $args{$attr} =~ ATTRS()->{$attr}
        );
    }
    return bless(\%args, $class);
}

sub to_hash {
    my ($self) = @_;
    return { %{ $self } };
}

sub load_from_line { ... }

1;

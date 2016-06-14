package PM::Log;
use strict;
use warnings;
use Carp qw/confess/;
use IO::File;
use PM;
use PM::Utils qw/:TIME/;
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

sub format_ts   { ... }
sub compare_cb  { ... }

sub whats_up {
    my ($self, %opts) = @_;
    my $config = PM->handle()->config();
    PM::Log::Exception::BadAfterOpt->throw() if (
        defined($opts{'after'}) &&
        $opts{'after'} !~ PM::Log::Entry::ATTRS()->{'hash'}
    );

    $self->_adjust_cache();
    
    my $res = [];
    return $res if ($self->{'_cache'}->is_empty());
    
    my $continue = sub {
        my ($entry) = @_;
        return undef if (
            !defined($entry) || (
                $opts{'after'} &&
                $entry->hash() eq $opts{'after'}
            )
        );
        push(@$res, $entry->to_hash());
        return 1;
    };
    $self->{'_cache'}->iterate_entries($continue);
    @$res = reverse @$res;
    return $res;
}

sub _init {
    my ($self) = @_;
    my $config = PM->handle()->config();
    $self->{'_whats_in_cache'} = {};
    $self->{'_cache'} = PM::Utils::FifoCache->new(
        'size' => $config->get('pm_max_entries'),
    );
    $self->_adjust_cache();
}

sub _adjust_cache {
    my ($self) = @_;
    return if ($self->_check_current_position());

    my $config = PM->handle()->config();
    my $max_uts = time() - $config->get('pm_max_time');
    my $max_ts = unix_to_ts($max_uts);
    my $mr_entry = $self->{'_cache'}->most_recent_entry();
    if ($mr_entry && $mr_entry->timestamp() ge $max_ts) {
        my $mr_uts = ts_to_unix($mr_entry->timestamp());
        $self->_refill_cache(
            $self->format_ts($mr_uts),
        );
    }
    else {
        $self->{'_cache'}->clear();
        $self->_refill_cache(
            $self->format_ts($max_uts)
        );
    }
    $self->_set_current_position();
}

sub _refill_cache {
    my ($self, $ts) = @_;
    my $config = PM->handle()->config();
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
    $searcher->locate($ts);
    my $entry_class = ref($self).'::Entry';
    while (!$file->eof()) {
        my $entry = $entry_class->load_from_line(
            $file->getline()
        );
        next if (
            !$entry ||
            exists($self->{'_whats_in_cache'}{$entry->hash()})
        );
        my $replaced_entry = $self->{'_cache'}->add($entry);
        $self->{'_whats_in_cache'}{$entry->hash()} = $entry;
        delete(
            $self->{'_whats_in_cache'}{$replaced_entry->hash()}
        ) if ($replaced_entry);
    }
    $file->close();
}

sub _set_current_position {
    my ($self) = @_;
    my $config = PM->handle()->config();
    $self->{'_current_position'} =
        join('_', (stat($config->get('pm_log')))[2, 7]);
}

sub _check_current_position {
    my ($self) = @_;
    my $config = PM->handle()->config();
    return ($self->{'_current_position'} // '') eq
        join('_', (stat($config->get('pm_log')))[2, 7]);
}

package PM::Log::Exception::BadAfterOpt;
sub throw {
    my ($class) = @_;
    die bless(\$class, $class);
}

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
    'hash'      => qr/^[a-zA-Z0-9]+$/,
};
{
    no strict 'refs';
    for my $attr (keys %{ ATTRS() }) {
        *{ __PACKAGE__ . "::$attr" } = sub { $_[0]->{$attr} };
    }
}

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
    return +{ map { $_ => $self->{$_} } keys %{ ATTRS() } };
}

sub load_from_line { ... }

1;

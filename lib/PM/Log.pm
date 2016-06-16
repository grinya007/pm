package PM::Log;
use strict;
use warnings;
use Carp qw/confess/;
use IO::File;
use PM;
use PM::Utils qw/:TIME/;
use PM::Utils::FifoCache;
use PM::Utils::LogSearch;

#   
#   Description
#
#   Base class that implements package manager independent
#   methods to keep track of what's happening to the packages
#   relying on package menagers history logs.
#   Please refer to lib/PM.pm module for terms of use
#   and architectural details.
#

sub new {
    my ($class) = @_;
    confess('this is abstract class') if (
        $class eq __PACKAGE__
    );
    my $config = PM->handle()->config();
    my $self = bless({

        # will keep O(1) accessible handbook of
        # hash-sums of entries that are currently cached
        # it makes sense upon adjusting cache
        # to insure against duplicates
        '_whats_in_cache'   => {},

        # cache will keep loaded log entry objects
        # in specifically same order as they are in log file
        '_cache'            => PM::Utils::FifoCache->new(
            'size'              => $config->get('pm_max_entries'),
        ),

    }, $class);
    # not creating accessors here since both
    # attributes are definitely private

    # initial cache adjustment
    # will read log file from not erlier than (time - pm_max_time)
    # and put to cache not more than pm_max_entries entries
    # (more precisely it may put more but overage entries
    # are replaced in FIFO order)
    $self->_adjust_cache();

    return $self;
}

# parse_ts_cb: must be implemented in subclass
#   takes no arguments
#   returns reference to a callback function
#   that will be called on each line of log
#   upon searching, the function will be given
#   a line of log as the single argument
#   if the line contains log specific timestamp
#   it is parsed and returned as unix epoch integer of seconds
#   for futher comparison against sought-for timestamp with <=> operator
#   else if line doesn't contain timestamp undef is returned,
#   so the line will be simply skipped
sub parse_ts_cb  { ... }

# the main and the only interface the whole system is all about
# returns an array reference of log entries from cache (unblessed to hashes)
# may take "after" option that be the hash-sum of log entry
# that is last known to the caller
# if given "after" will return only more recent entries than
# one that's identified by that hash-sum, or empty array reference if
# nothing happened in there
# Also throws PM::Log::Exception::BadAfterOpt in case when
# "after" is given yet it doesn't meet the constraint
# defined in the package below
sub whats_up {
    my ($self, %opts) = @_;
    my $config = PM->handle()->config();
    PM::Log::Exception::BadAfterOpt->throw() if (
        defined($opts{'after'}) &&
        $opts{'after'} !~ PM::Log::Entry::ATTRS()->{'hash'}
    );

    # checks for cached log completeness
    # reads log tail if file size or inode number
    # changed since last adjustment
    $self->_adjust_cache();
    
    my $res = [];

    # a short circuit
    return $res if ($self->{'_cache'}->is_empty());
    
    # PM::Utils::FifoCache iterates entries internally
    # and calls callback on each entry
    # please refer to lib/PM/Utils/FifoCache.pm
    # for details on how it actually works
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

    # unfortunately iterator works in reversed order
    # that's by design, small yet pity trade-off
    @$res = reverse @$res;

    return $res;
}

# log cache adjustment
# here we make a decision of
# is it time to opean and read log file again
sub _adjust_cache {
    my ($self) = @_;

    # inode and size haven't changed, outta here
    return if ($self->_check_current_position());

    my $config = PM->handle()->config();
    my $min_uts = time() - $config->get('pm_max_time');
    my $min_ts = unix_to_ts($min_uts);
    my $mr_entry = $self->{'_cache'}->most_recent_entry();
    
    if ($mr_entry && $mr_entry->timestamp() ge $min_ts) {
        
        # we still hope to escape doing a minor tailing
        my $mr_uts = ts_to_unix($mr_entry->timestamp());
        $self->_refill_cache('from' => $mr_uts);
    }
    else {

        # too much time passed, performing a whole
        # interval reading like we done initially
        $self->{'_cache'}->clear();
        %{ $self->{'_whats_in_cache'} } = ();
        $self->_refill_cache('from' => $min_uts);
    }

    # remember current file size and inode number
    $self->_set_current_position();
}

# opening/searching/reading/closing log file here
sub _refill_cache {
    my ($self, %opts) = @_;
    my $config = PM->handle()->config();
    
    # open
    my $file = IO::File->new(
        '<' . $config->get('pm_log')
    );
    confess(
        'failed to open '.$config->get('pm_name').' log: '.$!
    ) unless ($file);

    # search
    my $searcher = PM::Utils::LogSearch->new(
        'log'       => $file,
        'parse_ts'  => $self->parse_ts_cb(),
    );
    $searcher->locate($opts{'from'});

    # read
    my $entry_class = ref($self).'::Entry';
    while (!$file->eof()) {

        # load_from_line is explained in the package below
        my $entry = $entry_class->load_from_line(
            $file->getline()
        );

        # if no luck upon entry parsing
        # or entry is already in cache — skipping it
        next if (
            !$entry ||
            exists($self->{'_whats_in_cache'}{$entry->hash()})
        );

        # not forgetting to forget replaced entries and to
        # remember new ones
        my $replaced_entry = $self->{'_cache'}->add($entry);
        $self->{'_whats_in_cache'}{$entry->hash()} = $entry;
        delete(
            $self->{'_whats_in_cache'}{$replaced_entry->hash()}
        ) if ($replaced_entry);
    }

    # close
    $file->close();
}

# in short, the main architectural decision is
# about below two functions
sub _set_current_position {
    my ($self) = @_;
    my $config = PM->handle()->config();
    $self->{'_current_position'} =
        join('_', (stat($config->get('pm_log')))[2, 7]);
}

# especially this one
# here is the only system call that is performed
# repeatedly when nothing happens
# yet client needs to be sure that nothing happens
# it is that the realtime monitoring means
sub _check_current_position {
    my ($self) = @_;
    my $config = PM->handle()->config();
    return ($self->{'_current_position'} // '') eq
        join('_', (stat($config->get('pm_log')))[2, 7]);
}

# dummy exception class
# just to let caller-side to distinguish
# whether something unrecoverable happened or just
# invalid args passed
package PM::Log::Exception::BadAfterOpt;
sub throw {
    my ($class) = @_;
    die bless(\$class, $class);
}


package PM::Log::Entry;
use strict;
use warnings;
use Carp qw/confess/;

#
#   Description
#
#   Log entry base class
#   Implements validation of arguments upon object construction
#   and a little to_hash() unbless function
#

use constant 'ATTRS' => {
    'action'    => qr/^(?:install|remove)$/,
    'timestamp' => qr/^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$/,
    'package'   => qr/^[-+\.\~_a-zA-Z0-9]+$/,
    'version'   => qr/^[-+\.\~_a-zA-Z0-9]+$/,
    'arch'      => qr/^[-+\.\~_a-zA-Z0-9]+$/,
    'hash'      => qr/^[a-zA-Z0-9]+$/,
};
{
    # it might have been better to use Mojo::Base's has()
    # for this magic but generally I decided not to have
    # any external dependencies (other than come with perl >= 5.10.0)
    # here in PM::* modules and PM itself leaving a way to
    # use this monitoring system anywhere
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

# load_from_line: must be implemented in subclass
#   taking the line as the first argument
#   returns entry object if happened to parse one
#   or undef otherwise
#   DISCLAIMER: package managers that logs more than one entry
#   on a single line are currently not supported (e.g. apt)
#   it will be fixed in future releases
sub load_from_line { ... }

sub to_hash {
    my ($self) = @_;
    return +{ map { $_ => $self->{$_} } keys %{ ATTRS() } };
}

1;

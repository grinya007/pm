package PM;
use strict;
use warnings;
use feature qw/state/;
use Carp qw/confess/;
use PM::Utils::Config;

#
#   Desctiption
#
#   An entrypoint for the package monitoring system.
#   It puts the PM::* things together and keeps them
#   linked in a singleton through entire application
#   runtime.
#
#   Synopsis
#
#   use PM;
#
#   my $pm = PM->new(
#       'app_dir' => '/path/to/root/folder/of/this/repo'
#   );
#
#   # Assuming you have config at
#   # /path/to/root/folder/of/this/repo/etc/conf
#   # Please refer to lib/PM/Utils/Config.pm for
#   # details on config format
#   # basically config must provide:
#   #
#   #   pm_name         = [ name of package manager ]
#   #   pm_log          = [ /path/to/package/managers/history.log ]
#   #   pm_max_time     = [ time frame to look behind in seconds ]
#   #   pm_max_entries  = [ cached actions limit ]
#   #
#   # Unfortunately there are no defaults for any
#   # of these values.
#
#   my $most_recent_actions_portion =
#       $pm->log_handle()->whats_up();
#
#   # now $most_recent_actions_portion
#   # will keep an array reference of actions
#   # that were recently undertaken by package manager
#   #
#   #   [
#   #       {
#   #           'timestamp' => '2016-06-16 20:20:00',
#   #           'action'    => 'install',
#   #           'package'   => 'perl-Mojolicious',
#   #           'version'   => '5.60-2.4.1',
#   #           'arch'      => 'noarch',
#   #           'hash'      => '768838aef4381fa5c3dc2a069d67355f',
#   #       },
#   #       ...
#   #   ]
#   
#   # as time passes one may want to know if there
#   # are new installs or removes occurred
#
#   my $more_of_them;
#   if (@$most_recent_actions_portion) {
#       $more_of_them = $pm->log_handle()->whats_up(
#           'after' => $most_recent_actions_portion->[-1]{'hash'}
#       );
#   }
#   else {
#       $more_of_them = $pm->log_handle()->whats_up();
#   }
#
#   Once $pm object is constructed it is accessible
#   from anywhere in the code with
#
#   use PM;
#   my $pm = PM->handle();
#
#   The subsequent attempts to call PM->new(...) will fail.
#


sub new {
    my ($class, %args) = @_;
    confess('where we are?') unless (
        $args{'app_dir'} && -d $args{'app_dir'}
    );

    my $self = bless({
        'app_dir'       => $args{'app_dir'},

        # log_handle will be built later on in this constructor
        'log_handle'    => undef,


        'config'        => PM::Utils::Config->new(
            'file'      => $args{'app_dir'}.'/etc/conf'
        ),
    }, $class);

    # from here $self becomes a singleton
    $class->handle($self);

    # the proper package manager driver is loaded
    # dymamically
    my $log_class = 
        'PM::Log::'.$self->{'config'}->get('pm_name');
    eval "require $log_class";
    confess("failed to load $log_class: $@") if ($@);
    
    # we also need to check if proper log entry class
    # is provided along with driver
    my $log_entry_class = $log_class.'::Entry';
    unless ($log_entry_class->isa('PM::Log::Entry')) {
        eval "require $log_entry_class";
        confess(
            "failed to load $log_entry_class: $@"
        ) if ($@);
    }

    # all clear, assigning log_handle attribute
    # please refer to lib/PM/Log.pm for details
    # on drivers base class
    $self->{'log_handle'} = $log_class->new();

    return $self;
}

# creating read-only accessors
sub app_dir     { $_[0]->{'app_dir'}    }
sub config      { $_[0]->{'config'}     }
sub log_handle  { $_[0]->{'log_handle'} }

# besides keeping the singleton this class method
# is also concerned with initialization consistency
sub handle {
    my ($class, $self) = @_;
    state $singleton;
    confess('not yet initialized') unless (
        $singleton || $self
    );
    return $singleton unless ($self);
    confess('already initialized') if ($singleton);
    confess('please observe decorum') if (
        ref($self) ne __PACKAGE__
    );
    $singleton = $self;
}

1;

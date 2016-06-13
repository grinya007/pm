package PM;
use strict;
use warnings;
use feature qw/state/;
use Carp qw/confess/;

use PM::Utils::Config;

sub new {
    my ($class, %args) = @_;
    confess('where we are?') unless (
        $args{'app_dir'} && -d $args{'app_dir'}
    );
    my $self = bless({
        'app_dir'       => $args{'app_dir'},
        'config'        => undef,
        'log_handle'    => undef,
    }, $class);
    $self->_init();
    return $self;
}

sub app_dir     { $_[0]->{'app_dir'}    }
sub config      { $_[0]->{'config'}     }
sub log_handle  { $_[0]->{'log_handle'} }

sub handle {
    my ($class, $self) = @_;
    state $singleton;
    confess('not initialized') unless ($singleton || $self);
    return $singleton unless ($self);
    confess('already initialized') if ($singleton);
    confess('please observe decorum') if (
        ref($self) ne __PACKAGE__
    );
    $singleton = $self;
}

sub _init {
    my ($self) = @_;
    $self->{'config'} = PM::Utils::Config->new(
        'file' => $self->{'app_dir'}.'/etc/conf'
    );
    $self->handle($self);

    my $log_class = 'PM::Log::'.$self->{'config'}->get('pm_name');
    eval "require $log_class";
    confess("failed to load $log_class: $@") if ($@);

    $self->{'log_handle'} = $log_class->new();
}
 
1;

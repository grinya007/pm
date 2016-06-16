package PM::Utils::Config;
use strict;
use warnings;
use Carp qw/confess/;

#
#   Description
#
#   A simple config parser and holder class
#   
#   Format of the config file is:
#
#       # some comment on entry
#       key = value
#
#   key must match [_a-zA-Z0-9]+ pattern
#   spaces before and after the key are ignored
#   value may contain whatever characters
#   spaces before and after the value are ignored
#   If you need to keep leading or ending spaces
#   along the value as a part of it then use ['"] quotes
#
#       key = ' value wrapped with spaces '
#
#   The config file may contain no values at all
#
#       key_1 =
#       key_2 =
#
#   then you will be able to assign values using
#   environment variables upon application process
#   execution just give the same keys in upper case
#
#       KEY_1=foo KEY_2=bar ./my_app_with_pm_utils_config_onboard.pl
#
#   inside app these values will be reachable
#   through $config_object->get('key_1').
#   Also, values given in config file may be 
#   overridden with env vars in same manner
#
#   The config object is supposed to be kept
#   inside some environment singleton object
#   to insure against repeated config file reads
#   upon runtime.
#
#

# the constuctor reads, and saves config
# inside a private attribute
sub new {
    my ($class, %args) = @_;
    confess(
        'please provide file => '.
        '[ /path/to/config/file.conf ]'
    ) unless (
        $args{'file'} && -f $args{'file'}
    );

    my $fh;
    confess('failed to open config file: '.$!) unless (
        open($fh, '<', $args{'file'})
    );
    my $cfg = $class->_parse_lines([<$fh>]);
    close($fh);

    for my $key (keys %$cfg) {
        $cfg->{$key} = $ENV{uc($key)} // $cfg->{$key};
    }

    return bless({
        'file' => $args{'file'},
        '_cfg' => $cfg,
    }, $class);
}

# use this method to get config values by its keys
# it defends against key mistypes or other kinds of
# inconsistency by raising "no config for key" error
sub get {
    my ($self, $key) = @_;
    confess('please provide a key as first argument') unless (
        defined $key
    );
    confess('no config for '.$key) unless (
        exists $self->{'_cfg'}{$key}
    );
    return $self->{'_cfg'}{$key};
}

# parser
sub _parse_lines {
    my ($class, $lines) = @_;
    my $cfg = +{
        map {
            /^\s*([_a-zA-Z0-9]+)\s*=\s*('|")?(.*?)(?(2)\2)\s*$/;
            $1 ? ( $1 => $3 ) : ()
        } @$lines
    };
    return $cfg;
}


1;

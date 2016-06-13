package PM::Utils::Config;
use strict;
use warnings;
use Carp qw/confess/;

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
    my $cfg_hash = $class->_parse_lines([<$fh>]);
    close($fh);

    return bless({
        'file' => $args{'file'},
        '_cfg' => $cfg_hash,
    }, $class);
}

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

sub _parse_lines {
    my ($class, $lines) = @_;
    my $cfg = {
        map {
            /^\s*([_a-zA-Z0-9]+)\s*=\s*('|")?(.*?)(?(2)\2)\s*$/;
            $1 ? ( $1 => $3 ) : ()
        } @$lines
    };
    for my $key (keys %$cfg) {
        $cfg->{$key} = $ENV{uc($key)} // $cfg->{$key};
    }
    return $cfg;
}


1;

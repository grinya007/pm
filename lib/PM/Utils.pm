package PM::Utils;
use strict;
use warnings;

use Carp qw/confess/;
use POSIX qw/strftime/;
use Time::Local;

use base 'Exporter';
our @EXPORT = qw//; 
our @EXPORT_OK = qw/
    is_int
    json_encode
/;
our %EXPORT_TAGS = (
    TIME    => [qw/
        is_valid_ts
        unix_to_ts
        ts_to_unix
    /],
);
{
    my %export;
    @export{ map { @$_ } values %EXPORT_TAGS } = ();
    push @EXPORT_OK, keys %export;
}

sub is_int {
    my ($int) = @_;
    return undef unless (defined($int));
    no warnings 'numeric';
    return undef unless ($int eq int($int));
    return 1;
}

sub json_encode {
    my ($val) = @_;
    ref($val) eq 'ARRAY' && return '['.
        join(',', map { json_encode($_) } @{ $val }).
    ']';
    ref($val) eq 'HASH'  && return '{'.
        join(',', map { '"'.$_.'":' .
        json_encode($val->{$_}) } keys %{ $val }).
    '}';
    if (!ref($val) && defined($val)) {
        $val =~ s#\\#\\\\#g;
        $val =~ s#\'#\\'#g;
        $val =~ s#"#\\"#g;
        $val =~ s#<#\\x3C#g;
        $val =~ s#>#\\x3E#g;
        $val =~ s#\n#\\n#g;
        $val =~ s#\r#\\r#g;
        return '"'.$val.'"';
    }
    else {
        return '""';
    }
}

# :TIME utils
use constant 'TSRE' => 
    qr/^(\d{4})-(\d{2})-(\d{2})(?: (\d{2}):(\d{2}):(\d{2})(?:(\.\d{1,9}))?)?$/;

sub is_valid_ts {
    my ($ts) = @_;
    return undef unless ($ts);
    return undef unless ($ts =~ TSRE());
    return eval {
        timelocal(($6||0)+0, ($5||0)+0, ($4||0)+0, $3+0, $2-1, $1+0)
    };
}

sub ts_to_unix {
    my ($ts) = @_;
    my $unix = is_valid_ts($ts);
    confess(
        'ts is invalid'.($@ ? ': '.$@ : '')
    ) unless (defined($unix));
    return $unix;
}

sub unix_to_ts {
    my ($unix) = @_;
    confess('bad unix ts') unless (is_int($unix));
    return strftime('%F %T', localtime($unix));
}


1;

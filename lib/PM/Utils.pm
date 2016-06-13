package PM::Utils;
use strict;
use warnings;
use base 'Exporter';
our @EXPORT = qw//; 
our @EXPORT_OK = qw/
    is_int
    json_encode
/;
our %EXPORT_TAGS = (
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

1;

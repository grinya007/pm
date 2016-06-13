use lib 'lib';



#use PM::Utils::FifoCache;

#my $c = PM::Utils::FifoCache->new('size' => 10);
#for (qw/foo bar baz qux flu ent prl rgx/) {
    #$c->add($_);
#}

#use Data::Dumper;
#print Dumper $c;
#print Dumper $c->get_all();

#__END__
#use PM::Utils::Config;

#my $cfg = PM::Utils::Config->new('file' => 'etc/conf');

#use Data::Dumper;
#print Dumper $cfg;
#print $cfg->get('pm_name'), "\n";


#__END__
use IO::File;
use PM::Utils::LogSearch;

my $l = IO::File->new('</var/log/zypp/history');
my $re = qr/^(\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d)|/;
my $r = 0;
my $rl = 0;
my $c = sub {
    my ($ts, $l) = @_;
    use bytes;
    $r += length($l);
    $rl++;
    my ($lts) = $l =~ $re;
    return undef unless (defined $lts);
    #warn "sts:$ts lts:$lts\n";
    return $ts cmp $lts;
};

my $s = PM::Utils::LogSearch->new(
    'log' => $l,
    'cmp' => $c,
);

#$s->locate('2016-06-07 17:21:27');
$s->locate('2016-06-07 17:21:27', 'exclusive' => 1);
printf "read %d bytes in %d lines\n", $r, $rl;

print $l->getline() for 1..10;

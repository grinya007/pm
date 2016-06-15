#!/usr/bin/env perl
use Mojolicious::Lite;

use FindBin qw/$RealBin/;
use lib "$RealBin/lib";

use PM;
my $pm = PM->new('app_dir' => $RealBin);

get '/' => sub {
    my ($c) = @_;
    $c->render(
        'pmname'    => $pm->config()->get('pm_name'),
        'elimit'    => $pm->config()->get('pm_max_entries'),
        'tlimit'    => $pm->config()->get('pm_max_time'),
        'rinterval' => $pm->config()->get('pm_refresh'),
    );
} => 'index';

websocket '/whats_up' => sub {
    my ($c) = @_;
    $c->on('json' => sub {
        my ($c, $req) = @_;
        my $tail;
        if ($req->{'after'}) {
            eval {
                $tail = $pm->log_handle()->whats_up(
                    'after' => $req->{'after'}
                );
            };
            if ($@) {
                if (ref($@) eq 'PM::Log::Exception::BadAfterOpt') {
                    return $c->send({'json' => {
                        'ok'    => \0,
                        'error' => 'bad "after" opt',
                    }});
                }
                else {
                    die $@;
                }
            }
        }
        else {
            $tail = $pm->log_handle()->whats_up();
        }
        $c->send({'json' => {
            'ok'    => \1,
            'tail'  => $tail,
        }});
    });
};

app->start();


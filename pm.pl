#!/usr/bin/env perl
use Mojolicious::Lite;

use FindBin qw/$RealBin/;
use lib "$RealBin/lib";

use PM;
use PM::Utils qw/:TIME/;
my $pm = PM->new('app_dir' => $RealBin);

get '/' => sub {
    my ($c) = @_;
    $c->render(
        'pmname' => $pm->config()->get('pm_name'),
        'elimit' => $pm->config()->get('pm_max_entries'),
        'tlimit' => $pm->config()->get('pm_max_time'),
    );
} => 'index';

get '/whats_up' => sub {
    my ($c) = @_;

    my $tail;
    if (my $ts = $c->param('after')) {

        return $c->render(
            'text'      => 'Invalid timestamp!',
            'status'    => 400
        ) unless (is_valid_ts($ts));

        $tail = $pm->log_handle()->whats_up(
            'after' => $ts
        );
    }
    else {
        $tail = $pm->log_handle()->whats_up();
    }

    $c->render('json' => $tail);
};

app->start();

__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
    <head>
        <title>Package Monitoring</title>
        <link rel="stylesheet" href="/pm.css"/>
        <link
            rel="stylesheet"
            href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css"
            integrity="sha384-1q8mTJOASx8j1Au+a5WDVnPi2lkFfwwEAa8hDDdjZlpLegxhjVME1fgjWPGmkzs7"
            crossorigin="anonymous"
        >
        <script
            type="text/javascript"
            src="https://ajax.googleapis.com/ajax/libs/jquery/2.2.4/jquery.min.js"
        ></script>
        <script
            type="text/javascript"
            src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js"
            integrity="sha384-0mSbJDEHialfmuBBQP6A4Qrprq5OVfW37PRR3j5ELqxss1yVqOtnepnHVP9aJ7xS"
            crossorigin="anonymous"
        ></script>
        <script type="text/javascript" src="/pm.js"></script>
        <script type="text/javascript">
            pm.entriesLimit = <%= $elimit %>;
        </script>
    </head>
    <body>
        <div class="header bottom-align-text">
            <span class="logo">pm</span>
            <span class="title">
                yet another package monitoring system (by Gregory Arefyev <%
                %><a href="https://github.com/grinya007/pm" target="_blank">github</a>)
            </span>
            <span class="settings pull-right">
                <pre>Config: package manager name: <%= $pmname %>; <%
                %>entries limit: <%= $elimit %> entries; <%
                %>time limit: <%= $tlimit %> seconds</pre>
            </span>
        </div>
        <div class="container">
            <div class="row">
                <span class="col-sm-6">
                    <h2>installed</h2>
                    <table class="table table-striped log-table install">
                        <thead>
                            <tr>
                                <th>timestamp</th>
                                <th>package name</th>
                                <th>version</th>
                                <th>arch</th>
                            </tr>
                        </thead>
                        <tbody>
                        </tbody>
                    </table>
                </span>
                <span class="col-sm-6">
                    <h2>removed</h2>
                    <table class="table table-striped log-table remove">
                        <thead>
                            <tr>
                                <th>timestamp</th>
                                <th>package name</th>
                                <th>version</th>
                                <th>arch</th>
                            </tr>
                        </thead>
                        <tbody>
                        </tbody>
                    </table>
                </span>
            </div>
        </div>
    </body>
</html>

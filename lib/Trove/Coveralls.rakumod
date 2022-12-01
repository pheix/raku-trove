unit class Trove::Coveralls;

use HTTP::UserAgent;
use HTTP::Request::Common;
use HTTP::Request::FormData;
use JSON::Fast;
use Test;

has Bool $.test = False;
has Str  $.endpoint;
has Str  $.token;
has Str  $.origin;

method send(List :$files!) returns Int {
    return 1 unless $!token && $!endpoint;

    return 2 unless $files.elems;

    (my $gitbranch = %*ENV<GITBRANCH> // self.run_command(:command('git branch --show-current'))) ~~ s/<[\n\r]>+//;

    my $githead = self.run_command(:command('git log -1 --pretty=format:\'{id:"%H",author_name:"%aN",author_email:"%aE",committer_name:"%cN",committer_email:"%cE",message:"%f"}\''));

    my $coverals = {
        repo_token     => $!token,
        service_job_id => %*ENV<CI_JOB_ID>,
        service_name   => self.^name,
        source_files   => $files,
        git => {
            head    => $githead,
            branch  => $gitbranch,
            remotes => [{name => 'origin', url => $!origin}]
        }
    };

    my $coveralls_json = to-json($coverals);

    my $fd = HTTP::Request::FormData.new;

    $fd.add-part('json_file', $coveralls_json, :content-type('application/octet-stream'), :filename('coverage.json'));

    my $response;

    my $req = POST(
        $!endpoint,
        Content-Type => $fd.content-type,
        content => $fd.content,
    );

    try {
        $response = HTTP::UserAgent.new.request($req);
 
        CATCH {
            default {
                self.msg(:m(sprintf("coverall endpoint <%s> request exception <%s>: %s", $!endpoint, .^name, .Str)));
            }
        }
    }

    return 3 if !$response;

    if $response.is-success {
        self.msg(:m(from-json($response.content)<url>));
    }
    else {
        self.msg(:m(to-json(from-json($response.content), :pretty)));

        return 4;
    }

    return 0;
}

method run_command(Str :$command!) returns Str {
    return unless $command ne q{};

    my @run  = $command.split(/\s+/, :skip-empty);
    my $proc = run @run, :out, :env(%*ENV);

    return $proc.out.slurp: :close;
}

method msg(Str :$m) {
    $!test ?? diag($m) !! $m.say;
}

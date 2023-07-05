unit class Trove::Coveralls;

use HTTP::UserAgent;
use HTTP::Request::Common;
use HTTP::Request::FormData;
use JSON::Fast;
use Test;

has Bool $.dump   = False;
has Bool $.silent = False;
has Bool $.test   = False;
has Str  $.gitpath;
has Str  $.endpoint;
has Str  $.token;
has Str  $.origin;
has Str  $.date = DateTime.now(
    formatter => { sprintf "%d-%02d-%02d_%02d-%02d-%02d",
        .year, .month, .day, .hour, .minute, .second }).Str;

method send(List :$files!) returns Int {
    return 1 unless $!token && $!endpoint;

    return 2 unless $files.elems;

    my $gitbranch;
    my $githead;

    if !$!test {
        my $gitpath  = $!gitpath && ($!gitpath ~ "/.git").IO.d ?? sprintf("--git-dir=%s/.git", $!gitpath) !! q{};
        ($gitbranch  = %*ENV<CI_COMMIT_BRANCH> // self.run_command(:command(sprintf("git %s branch --show-current", $gitpath)))) ~~ s/<[\n\r]>+//;

        (my $git = self.run_command(:command(sprintf("git %s log -1 --pretty=format:'%s'", $gitpath, '{"id":"%H","author_name":"%aN","author_email":"%aE","committer_name":"%cN","committer_email":"%cE","message":"%f"}')))) ~~ s:g/'\''//;

        try {
            $githead = from-json($git);

            CATCH {
                default {
                    self.msg(:m(sprintf("parse git head exception <%s>: %s", .^name, .Str)));
                }
            }
        }
    }

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

    if $!dump {
        # self.msg(:m($coveralls_json));

        sprintf("coveralls-request-%s.json", $!date).IO.spurt($coveralls_json);
    }

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

method run_command(Str :$command!, Code :$callback) returns Str {
    return unless $command ne q{};

    my @run  = $command.split(/\s+/, :skip-empty);
    my $proc = run @run, :out, :env(%*ENV);

    if $proc.exitcode {
        $callback(:output($proc.out.slurp: :close)) if $callback;

        X::AdHoc.new(:payload(sprintf("command <%s> exit code %d", $command, $proc.exitcode))).throw;
    }

    return $proc.out.slurp: :close;
}

method msg(Str :$m) {
    return if $!silent;

    $!test ?? diag($m) !! $m.say;
}

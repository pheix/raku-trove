unit class Trove;

use Digest::MD5;
use Terminal::ANSIColor;
use Trove::Config::Parser;
use Test;

has Str  $.configfile;
has Str  $.gitver;
has Str  $.currver;
has Str  $.skipped;
has      $.skippedstages;
has      @.coveragestats;

has Bool $.test          is default(False);
has Bool $.colorize      is default(False);
has Bool $.logfirststage is default(False);
has Rat  $.coverage      is default(0.0);
has Int  $.iterator      is default(0);
has Int  $.linesz        is default(64);
has Str  $.processor     is default('jq');
has Str  $.files_report  is default('[]');
has Str  $.www           is default('./www');
has Str  $.precomp       is default('./lib/.precomp');
has Str  $.origin        is default('git@gitlab.com:pheix-pool/core-perl6.git');
has Str  $.successtoken  is default(Digest::MD5.new.md5_hex('Trove'));
has Str  $.coveralls     is default('https://coveralls.io/api/v1/jobs');
has Str  $.date          is default(
    DateTime.now(
        formatter => { sprintf "%d-%02d-%02d_%02d-%02d-%02d",
            .year, .month, .day, .hour, .minute, .second }).Str
);

has Str  $.gitbranch      = %*ENV<CI_COMMIT_BRANCH> // q{};
has Str  $.testlog        = sprintf("./testreport.%s.log", $!date);
has Str  $.multipartdelim = sprintf("-----%s", Digest::MD5.new.md5_hex($!date));

has Hash $!env = {
    WWW     => $!www,
    GITVER  => $!gitver,
    CURRVER => $!currver,
}

enum EnvMode <environment cleanup>;

method debug returns Str {
    for self.^attributes -> $attr {
        sprintf("%15s: %s", $attr.name, ($attr.get_value(self).gist)).say;
    }

    return self.^name;
}

method run_command(Str :$command!) returns Str {
    return unless $command ne q{};

    my @run  = $command.split(/\s+/, :skip-empty);
    my $proc = run @run, :out, :env(%*ENV);

    return $proc.out.slurp: :close;
}

method process(Bool :$exit = True) returns Bool {
    %*ENV<PHEIXTESTENGINE> = 1;

    if !$!configfile || !$!configfile.IO.f {
        self.debugmsg(
            :m(sprintf("%s configuration file %s is not existed",
                colored('PANIC:', 'red bold'),
                    colored($!configfile, 'yellow'))));

        %*ENV<PHEIXTESTENGINE>:delete;

        exit 1 if $exit;

        return False;
    }

    my $testconfig = Trove::Config::Parser.new.process(
        :path($!configfile),
        :yaml($!processor eq 'yq' ?? True !! False)
    );

    if !$testconfig.keys || !$testconfig<stages> || !$testconfig<stages>.elems {
        self.debugmsg(
            :m(sprintf("%s no stages in configuration file are found",
                colored('WARNING:', 'yellow bold'))));

        exit 0 if $exit;

        return True;
    }

    self.process_stages(:stages($testconfig<stages>), :exit($exit));

    return True;
}

method check_output(
    Str  :$output!,
    Str  :$script!,
    Int  :$stageindex!,
    Hash :$stage!,
    Bool :$exit = True
) returns Bool {
    # $output.say if $output !~~ m:i/^$/;

    my $res = colored('OK', 'green');

    $res = colored('WARN', 'yellow') if $output ~~ m:i/^$/;
    $res = colored('SKIP', 'red') if $output ~~ m:i/'# skip'/;
    $res = colored('FAIL', 'red') if $output ~~ /'not ok'/;

    self.debugmsg(:m(sprintf("%02d. %-" ~ $!linesz ~ "s[ %s ]",
        $stageindex,
            sprintf("Testing %s", colored($script, 'yellow')), $res)));

    if $output ~~ /'not ok'/ {
        self.stage_env(:mode(cleanup), :stage($stage));
        return self.failure_exit(:stageindex($stageindex), :exit($exit));
    }

    return True;
}

method stage_is_skipped(Int :$stageindex!, Str :$script!) returns Bool {
    my Bool $is_skipped = False;

    return True unless $stageindex > 0;

    return False unless $!skippedstages && $!skippedstages.elems > 0;

    for $!skippedstages.cache -> $index {
        next unless $index;

        next if $index != $stageindex;

        $is_skipped = True;
        $!skipped = sprintf("# SKIP: stage no.%d is skipped via command line", $stageindex);

        self.debugmsg(
            :m(sprintf("%s %-" ~ $!linesz ~ "s",
                colored(sprintf("%02d.", $stageindex), 'black on_white'),
                    sprintf("Skipping tests for %s", colored($script, 'yellow')))),
            :nl(False),
        );

        self.write_to_log(:data(sprintf("----------- STAGE no.%d -----------\n%s\n", $stageindex, $!skipped)));

        last;
    }

    return $is_skipped;
}

method stage_env(EnvMode :$mode = (environment), Hash :$stage!) returns Bool {
    return False unless $stage.keys && $stage{$mode} && $stage{$mode}.elems;

    for $stage{$mode}.kv -> $commanindex, $command {
        if $command ~~ /('unset'|'export')\s*(.*)/ {
            my $commarg = $1;

            %*ENV{$commarg}:delete if $mode == cleanup;

            if $mode == environment {
                my @pair = $commarg.split(q{=}, :skip-empty);

                %*ENV{@pair[0]} = @pair[1] if @pair && @pair.elems == 2;
            }
        }
    }

    return True;
}

method get_stage_command(Hash :$stage!) returns Str {
    return unless $stage.keys && $stage<test>;

    my $command = $stage<test>;

    return $command unless $stage<args> && $stage<args>.elems;

    $stage<args>.map({
        my $k = $_;
        my $v = %*ENV{$k} // $!env{$k} // q{}; $command ~~ s:g/\%?\$?$k\%?/$v/;
    });

    return $command;
}

method process_stages(
    List :$stages!,
    Bool :$issubstage = False,
    Int  :$parentindex,
    Bool :$exit = True
) returns Bool {
    return False unless $stages.elems;

    for $stages.kv -> $index, $stage {
        my $stageindex          = $index + 1;
        @!coveragestats[$index] = 0;

        my $command = self.get_stage_command(:stage($stage));
        (my $script = $command) ~~ s:g/^(perl|perl6|raku)\s*(\S+).*/$1/;

        if !$issubstage && self.stage_is_skipped(:stageindex($stageindex), :script($script)) {
            self.debugmsg(:m(sprintf("[ %s ]", colored('SKIP', 'red'))));
        }
        else {
            self.stage_env(:stage($stage));

            self.check_output(
                :output(self.run_command(:command($command))),
                :script($script),
                :stageindex($parentindex // $stageindex),
                :stage($stage),
                :exit($exit)
            );

            self.process_stages(
                :stages($stage<substages>),
                :parentindex($parentindex // $stageindex),
                :issubstage(True),
                :exit($exit)
            ) if $stage<substages> && $stage<substages> ~~ List;

            self.stage_env(:mode(cleanup), :stage($stage));
        }
    }

    return True;
}

method failure_exit(Int :$stageindex!, Bool :$exit = True) returns Bool {
    self.debugmsg(:m(sprintf("[ %s ]", colored(sprintf("error at stage %d", $stageindex), 'red'))));

    %*ENV<PHEIXTESTENGINE>:delete;

    exit 3 if $exit;

    return False;
}

method multipart_data(Str :$data!) returns Str {
    return Str;
}

method debugmsg(Str :$m!, Bool :$nl = True) {
    $!test ?? diag($m) !! ($nl ?? $m.say !! $m.printf);
}

method write_to_log(Str :$data!) returns Bool {
    return False unless $data ne q{};

    my $fh = $!testlog.IO.f ?? open($!testlog, :a) !! open($!testlog, :w);

    return False unless $fh;

    return False unless $fh.print($data);

    return False unless $fh.close;

    return True
}

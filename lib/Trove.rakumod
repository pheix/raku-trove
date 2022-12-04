unit class Trove;

use Digest::MD5;
use Terminal::ANSIColor;
use Trove::Config::Parser;
use Trove::Coveralls;
use Test;

has Str  $.configfile;
has Str  $.gitver;
has Str  $.currver;
has      $.skippedstages;
has      @.coveragestats;

has Bool $.silent        is default(False);
has Bool $.test          is default(False);
has Bool $.colorize      is default(False);
has Bool $.logfirststage is default(False);
has Rat  $.coverage      is default(0.0);
has Int  $.stages        is default(0);
has Int  $.iterator      is default(1);
has Int  $.linesz        is default(64);
has Str  $.processor     is default('jq');
has Str  $.files_report  is default('[]');
has Str  $.www           is default('./www');
has Str  $.origin        is default('git@gitlab.com:pheix-pool/core-perl6.git');
has Str  $.dummystoken   is default(Digest::MD5.new.md5_hex('Trove'));
has Str  $.coveralls     is default('https://coveralls.io/api/v1/jobs');
has Str  $.date = DateTime.now(
    formatter => { sprintf "%d-%02d-%02d_%02d-%02d-%02d",
        .year, .month, .day, .hour, .minute, .second }).Str;

has Str  $.testlog = sprintf("./testreport.%s.log", $!date);

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

method colored(Str $message, Str $markup) returns Str {
    return $!colorize ??
        colored($message, $markup) !!
            $message;
}

method run_command(Str :$command!) returns Str {
    return q{} if $!test;

    return Trove::Coveralls.new.run_command(:command($command));
}

method process(Bool :$exit = True) returns Bool {
    %*ENV<PHEIXTESTENGINE> = 1;

    if !$!configfile || !$!configfile.IO.f {
        self.debugmsg(
            :m(sprintf("%s configuration file %s is not existed",
                self.colored('PANIC:', 'red bold'),
                    self.colored($!configfile, 'yellow'))));

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
                self.colored('WARNING:', 'yellow bold'))));

        exit 0 if $exit;

        return True;
    }

    $!stages = $testconfig<stages>.elems;

    (1..$!stages).map({ @!coveragestats[$_ - 1] = 0; });

    self.process_stages(:stages($testconfig<stages>), :exit($exit));
    self.coveralls(:stages($testconfig<stages>));
    # @!coveragestats.gist.say;

    return True;
}

method check_output(
    Str  :$output!,
    Str  :$script!,
    Int  :$stageindex!,
    Hash :$stage!,
    Bool :$exit = True,
    Bool :$issubstage = False
) returns Bool {
    # $output.say if $output !~~ m:i/^$/;

    $!coverage     = $!iterator * 100 / $!stages;
    my $percentage = sprintf("%d%% covered", $!coverage);

    my $res = self.colored($percentage, 'green');

    $res = self.colored('OK', 'green')    if $issubstage;
    $res = self.colored('WARN', 'yellow') if $output ~~ m:i/^$/;
    $res = self.colored('SKIP', 'red')    if $output ~~ m:i/'# skip'/;
    $res = self.colored('FAIL', 'red')    if $output ~~ /'not ok'/;

    self.write_to_log(:data(sprintf("----------- STAGE no.%d -----------\n%s\n", $stageindex, $output)))
        if ($!logfirststage && $stageindex == 1) || $stageindex > 1;

    self.debugmsg(:m(sprintf("%02d. %-" ~ $!linesz ~ "s[ %s ]",
        $stageindex,
            sprintf("Testing %s", self.colored($script, 'yellow')), $res)))
                if !$issubstage;

    if $output ~~ /'not ok'/ {
        self.stage_env(:mode(cleanup), :stage($stage));
        return self.failure_exit(:stageindex($stageindex), :exit($exit));
    }

    if !$issubstage && $output !~~ m:i/'# skip'/ {
        $!iterator++;
        @!coveragestats[$stageindex - 1] = 100;
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
        my $skipped = sprintf("# SKIP: stage no.%d is skipped via command line", $stageindex);

        self.debugmsg(
            :m(sprintf("%s %-" ~ $!linesz ~ "s",
                self.colored(sprintf("%02d.", $stageindex), 'black on_white'),
                    sprintf("Skipping tests for %s", self.colored($script, 'yellow')))),
            :nl(False),
        );

        self.write_to_log(:data(sprintf("----------- STAGE no.%d -----------\n%s\n", $stageindex, $skipped)));

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
        my $stageindex = $index + 1;

        my $command = self.get_stage_command(:stage($stage));
        (my $script = $command) ~~ s:g/^(perl|perl6|raku)\s*(\S+).*/$1/;

        if !$issubstage && self.stage_is_skipped(:stageindex($stageindex), :script($script)) {
            self.debugmsg(:m(sprintf("[ %s ]", self.colored('SKIP', 'red'))));
        }
        else {
            self.stage_env(:stage($stage));

            self.check_output(
                :output(self.run_command(:command($command))),
                :script($script),
                :stageindex($parentindex // $stageindex),
                :stage($stage),
                :exit($exit),
                :issubstage($issubstage),
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
    self.debugmsg(:m(sprintf("[ %s ]", self.colored(sprintf("error at stage %d", $stageindex), 'red'))));

    %*ENV<PHEIXTESTENGINE>:delete;

    exit 3 if $exit;

    return False;
}

method coveralls(List :$stages!) returns Bool {
    if !%*ENV<CI_JOB_ID> {
        self.debugmsg(:m(sprintf("Skip send report to %s: CI/CD identifier is missed", self.colored('coveralls.io', 'yellow'))));

        return False;
    }

    if !%*ENV<COVERALLSTOKEN> {
        self.debugmsg(:m(sprintf("Skip send report to %s: token is missed", self.colored('coveralls.io', 'yellow'))));

        return False;
    }

    return False unless $stages.elems;

    my @files_report;

    for $stages.kv -> $index, $stage {
        my $stageindex = $index + 1;

        my $command = self.get_stage_command(:stage($stage));
        (my $script = $command) ~~ s:g/^(perl|perl6|raku)\s*(\S+).*/$1/;

        my $digest   = Digest::MD5.new.md5_hex($script ~ DateTime.now.Str);
        my $coverage = @!coveragestats[$index];

        @files_report.push({ name => $script, source_digest => $digest, coverage => [$coverage] });
    }

    my $ret = Trove::Coveralls
        .new(
            :token($!test ?? $!dummystoken !! %*ENV<COVERALLSTOKEN>),
            :endpoint($!coveralls),
            :origin($!origin),
            :test($!test),
            :silent($!silent))
        .send(:files(@files_report));

    self.debugmsg(:m(@files_report.map({$_.gist}).join(q{,}))) if $!test;

    return $ret == 0 ?? True !! False;
}

method debugmsg(Str :$m!, Bool :$nl = True) {
    return if $!silent;

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

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

enum EnvMode <set unset>;

method debug returns Str {
    for self.^attributes -> $attr {
        sprintf("%15s: %s", $attr.name, ($attr.get_value(self).gist)).say;
    }

    return self.^name;
}

method process(Bool :$exit = True) returns Bool {
    shell 'export PHEIXTESTENGINE=1';

    if !$!configfile || !$!configfile.IO.f {
        self.debugmsg(
            :m(sprintf("%s configuration file %s is not existed",
                colored('PANIC:', 'red bold'),
                    colored($!configfile, 'yellow'))));

        shell 'unset PHEIXTESTENGINE';

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

    for $testconfig<stages>.kv -> $index, $stage {
        my $stageindex          = $index + 1;
        @!coveragestats[$index] = 0;

        my $command = self.get_stage_command(:stage($stage));
        (my $script = $command) ~~ s:g/^(perl|perl6|raku)\s*(\S+).*/$1/;

        if self.stage_is_skipped(:stageindex($stageindex), :script($script)) {
            self.debugmsg(:m(sprintf("[ %s ]", colored('SKIP', 'red'))));
        }
        else {
            self.debugmsg(:m(sprintf("%02d. %-" ~ $!linesz ~ "s[ %s ]",
                $stageindex,
                    sprintf("Testing %s", colored($script, 'yellow')),
                            colored('OK', 'green'))));
        }
    }

    return True;
}

method check_output(Str :$output!, Int :$stage!) returns Bool {
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

method stage_env (EnvMode :$mode = (set), Int :$stage!, Int :$substage) {
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

method process_substages(Int :$stage!, Int :$substage) returns Bool {
    return True;
}

method failure_exit(Int :$stage!, Bool :$exit = True) returns Bool {
    self.debugmsg(:m(sprintf("[ %s ]", colored(sprintf("error at stage %d", $stage), 'red'))));

    shell 'unset PHEIXTESTENGINE';

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

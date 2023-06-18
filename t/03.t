use v6.d;
use Test;

use Trove;
use Trove::Coveralls;

my $silent = (%*ENV<TROVEDEBUG>.defined && %*ENV<TROVEDEBUG> == 1) ?? False !! True;
my @env    = <CI_JOB_ID COVERALLSENDPOINT COVERALLSTOKEN>;

plan 3;

use-ok 'Trove::Coveralls', 'Trove::Coveralls is used ok';

subtest {
    plan 1;

    set_env;

    my $cfn = './x/pheix-configs/test.conf.yaml';

    my $c = Trove::Config::Parser.new.process(:path($cfn), :yaml(True));

    my $r = Trove
        .new(:configfile($cfn), :test(True), :coveragestats((0..30)), :silent($silent))
        .coveralls(:stages($c<stages>)),

    nok $r, 'coveralls wrapper';

    unset_env;
}, 'check Coveralls wrapper';

subtest {
    plan 2;

    my $trv = Trove.new(:silent($silent), :stages(1), :test(True));

    my $fail = qq~
not ok 14 - save signing log
# Failed test 'save signing log'
# at ./t/07-blockchain-common.t line 789
    ~;

    my $fail_todo = qq~
not ok 14 - save signing log # TODO possible non-signer mode
# Failed test 'save signing log'
# at ./t/07-blockchain-common.t line 789
    ~;

     nok $trv.check_output(:output($fail), :script(~$*PROGRAM), :stageindex(1), :stage({}), :exit(False)), 'true failure';
     ok $trv.check_output(:output($fail_todo), :script(~$*PROGRAM), :stageindex(1), :stage({}), :exit(False)), 'true failure';
}, 'check output';

done-testing;

sub set_env {
    @env.map({%*ENV{$_} = ~1 unless %*ENV{$_} && %*ENV{$_} ne q{};});
}

sub unset_env {
    @env.map({%*ENV{$_}:delete});
}

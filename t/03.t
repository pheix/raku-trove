use v6.d;
use Test;

use Trove;
use Trove::Coveralls;

my @env = <CI_JOB_ID COVERALLSENDPOINT COVERALLSTOKEN>;

plan 2;

use-ok 'Trove::Coveralls', 'Trove::Coveralls is used ok';

subtest {
    plan 1;

    set_env;

    my $cfn = './x/pheix-configs/test.conf.yaml';

    my $c = Trove::Config::Parser.new.process(:path($cfn), :yaml(True));

    my $r = Trove
        .new(:configfile($cfn), :test(True), :coveragestats((0..30)))
        .coveralls(:stages($c<stages>)),

    ok $r, 'coveralls wrapper';

    unset_env;
}, 'check Coveralls wrapper';

done-testing;

sub set_env {
    @env.map({%*ENV{$_} = ~1;});
}

sub unset_env {
    @env.map({%*ENV{$_}:delete});
}

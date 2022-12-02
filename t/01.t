use v6.d;
use Test;

use Trove;

my $silent = (%*ENV<TROVEDEBUG>.defined && %*ENV<TROVEDEBUG> == 1) ?? False !! True;

plan 4;

use-ok 'Trove', 'Trove is used ok';

my $trove = Trove.new;

ok $trove, 'Trove object';

$trove.debug;
$trove.failure_exit(:stageindex(1), :exit(False));

subtest {
    plan 4;

    my $tmpfile = sprintf("/tmp/%s.json", time);
    ok $tmpfile.IO.spurt('{"array": ["str1", "str2"]}'), 'fake config is saved';

    nok Trove.new(:configfile('/tmp/fakepath/foo.bar'), :test(True), :silent($silent)).process(:exit(False)), 'config at fake path';
    ok Trove.new(:configfile($tmpfile), :test(True), :silent($silent)).process(:exit(False)), 'config with no stages';

    ok ($tmpfile.IO.f ?? unlink $tmpfile !! False), 'fake config unlink';
}, 'colored messages';

subtest {
    plan 2;

    ok Trove.new(:configfile('./x/pheix-configs/test.conf.json'), :test(True), :silent($silent)).process(:exit(False)), 'iterate over JSON';
    ok Trove.new(:skippedstages([29,30]), :configfile('./x/pheix-configs/test.conf.yaml'), :processor('yq'), :test(True), :silent($silent)).process(:exit(False)), 'iterate over YAML';
}, 'iterate over stages';

done-testing;

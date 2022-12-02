use v6.d;
use Test;

use Trove::Config::Parser;

plan 3;

use-ok 'Trove::Config::Parser', 'Trove::Config::Parser is used ok';

my $parser = Trove::Config::Parser.new;
my $json   = $parser.process(:path('./x/pheix-configs/test.conf.json'));
my $yaml   = $parser.process(:path('./x/pheix-configs/test.conf.yaml'), :yaml(True));

is $json<stages>.elems, $yaml<stages>.elems, 'stages num in yaml is equal to json';

if %*ENV<PHEIXTESTENGINE>:!exists {
    # diag('PHEIXTESTENGINE was not set');
    skip-rest('skip integration tests');

    exit;
}

is %*ENV<TROVE_ENV_VAR>, 'magic-trove-env-value', 'env var found';

done-testing;

use v6.d;
use Test;

use Trove::Config::Parser;

plan 2;

use-ok 'Trove::Config::Parser', 'Trove::Config::Parser is used ok';

my $parser = Trove::Config::Parser.new;
my $json   = $parser.process(:path('./x/pheix-configs/test.conf.json'));
my $yaml   = $parser.process(:path('./x/pheix-configs/test.conf.yaml'), :yaml(True));

is $json<stages>.elems, $yaml<stages>.elems, 'stages num in yaml is equal to json';

done-testing;

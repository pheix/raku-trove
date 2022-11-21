use v6.d;
use Test;

use Trove;

plan 1;

use-ok 'Trove', 'Trove is used ok';

diag(Trove.new.debug);

done-testing;

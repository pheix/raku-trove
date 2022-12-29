unit class Trove::Config::Parser;

use JSON::Fast;
use YAMLish;

method process(Str :$path!, Bool :$yaml = False, Str :$interpreter = 'raku') returns Hash {
    my $config = {};

    return $config unless $path && $path.IO.f;

    $config = $yaml ?? load-yaml($path.IO.slurp) !! from-json($path.IO.slurp);

    return $config unless $config<explore> && $config<explore>.keys;

    return {} unless $config<explore><base>.IO ~~ :d;

    my @matched;
    my @recursive = $config<explore><base>.IO;

    while @recursive {
        for @recursive.pop.dir -> $path {
            @matched.push({ test => sprintf("%s %s", ($config<explore><interpreter> // $interpreter), ~$path) })
                if $path.f && $path ~~ /<{$config<explore><pattern>}>/;

            @recursive.push($path) if $path.d && $config<explore><recursive>;
        }
    }

    return {} unless @matched && @matched.elems;

    return { stages => @matched.sort.list };
}

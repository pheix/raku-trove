unit class Trove::Config::Parser;

use JSON::Fast;
use YAMLish;

method process(Str :$path!, Bool :$yaml = False, Str :$interpreter = 'raku') returns Hash {
    return {} unless $path && $path.IO.f;

    my $config = $yaml ?? load-yaml($path.IO.slurp) !! from-json($path.IO.slurp);

    if $config<explore> && $config<explore>.keys {
        my @matched;
        my @recursive;

        if $config<explore><base>.IO ~~ :d {
            @recursive = $config<explore><base>.IO;
        }

        while @recursive {
            for @recursive.pop.dir -> $path {
                @matched.push({ test => sprintf("%s %s", ($config<explore><interpreter> // $interpreter), ~$path) })
                    if $path.f && $path ~~ /<{$config<explore><pattern>}>/;

                @recursive.push($path) if $path.d && $config<explore><recursive>;
            }
        }

        if @matched && @matched.elems {
            $config<stages>.push(|@matched.sort.list);
        }
    }

    return $config;
}

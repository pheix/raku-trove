unit class Trove::Config::Parser;

use JSON::Fast;
use YAMLish;

method process(Str :$path!, Bool :$yaml = False) returns Hash {
    return {} unless $path && $path.IO.f;

    return load-yaml($path.IO.slurp) if $yaml;

    return from-json($path.IO.slurp);
}

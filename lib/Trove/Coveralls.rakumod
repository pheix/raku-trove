unit class Trove::Coveralls;

has Str $.endpoint;
has Str $.token;

method send(List :$files!) returns Int {
    return 1 unless $!token && $!endpoint;

    return 2 unless $files.elems;

    return 0;
}

unit class Trove;

use Digest::MD5;


has Str  $.configfile;
has Str  $.gitver;
has Str  $.currver;
has Str  $.skipped;
has      @.skippedstages;
has      @.coveragestats;

has Bool $.colorize      is default(False);
has Bool $.logfirststage is default(False);
has Num  @.coverage      is default(0);
has Num  @.iterator      is default(0);
has Num  @.linesz        is default(64);
has Str  $.processor     is default('jq');
has Str  $.files_report  is default('[]');
has Str  $.www           is default('./www');
has Str  $.precomp       is default('./lib/.precomp');
has Str  $.origin        is default('git@gitlab.com:pheix-pool/core-perl6.git');
has Str  $.successtoken  is default(Digest::MD5.new.md5_hex('Trove'));
has Str  $.coveralls     is default('https://coveralls.io/api/v1/jobs');
has Str  $.date          is default(
    DateTime.now(
        formatter => { sprintf "%d-%02d-%02d_%02d-%02d-%02d",
            .year, .month, .day, .hour, .minute, .second }).Str
);

has Str  $.gitbranch      = %*ENV<CI_COMMIT_BRANCH> // q{};
has Str  $.testlog        = sprintf("./testreport.%s.log", $!date);
has Str  $.multipartdelim = sprintf("-----%s", Digest::MD5.new.md5_hex($!date));

method debug returns Str {
    $!date.say;
    $!successtoken.say;

    $!configfile.say;
    $!processor.say;
    $!currver.say;
    $!gitver.say;
    $!colorize.say;
    $!logfirststage.say;
    @!skippedstages.say;

    return self.^name;
}

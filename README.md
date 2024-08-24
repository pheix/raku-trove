# Trove test harness

## Concept

Yet another [test harness written in Raku](https://github.com/pheix/raku-trove) language and inspired by `bash` driven test tool built for [Pheix](https://gitlab.com/pheix/dcms-raku) content management system.

Generally `Trove` is based on idea to create the wrapper over the unit tests in `t` folder. But with out-of-the-box Gitlab or Github CI/CD integration, extended logging and test-dependable options.

`Trove` includes `trove-cli` script as a primary worker for batch testing. It iterates over pre-configured stages and runs specific unit test linked to the stage. `trove-cli` is console oriented — all output is printed to `STDOUT` and `STDERR` data streams. Input is taken from command line arguments.

## TL;DR

`Trove` Christmas recipes at Raku Advent 2022 blog: https://raku-advent.blog/2022/12/14/day-14-trove-yet-another-tap-harness

## Usage

1. Command line arguments
    * [Colors](#colors)
    * [Stages management](#stages-management)
    * [File processor configuration](#file-processor-configuration)
    * [Versions consistency](#versions-consistency)
    * [Target configuration file](#target-configuration-file)
    * [First stage logging policy](#first-stage-logging-policy)
    * [Origin repository](#origin-repository)
2. Test configuration files — JSON & YAML
    * Configuration file sections
        * [Explore](#explore)
        * [Stage and substage](#stage-and-substage)
        * [Mix it up!](#mix-it-up)
    * [Trivial test configuration example](#trivial-test-configuration-example)
    * [Pheix test suite configuration files](#pheix-test-suite-configuration-files)
3. Test coverage management
    * [Gitlab](#gitlab)
    * [Coveralls](#coveralls)
        * [Setup automatic coverage upload](#setup-automatic-coverage-upload)
4. [Log test session](#log-test-session)
5. Integration with CI/CD environments
    * [github.com](#githubcom)
    * [gitlab.com](#gitlabcom)

### Command line arguments

#### Colors

To bring colors to the output `-c` option is used:

    trove-cli -c --f=`pwd`/run-tests.conf.yml --p=yq

#### Stages management

To exclude specific stages from test `-s` option is used:

    trove-cli -c --s=1,2,4,9,10,11,12,13,14,25,26 --f=`pwd`/run-tests.conf.yml --p=yq

### File processor configuration

`trove-cli` takes test scenario from configuration file. Default format is JSON, but you can use YAML on demand, for now `JSON::Fast` and `YAMLish` processing modules (processors) are integrated. To switch between the processors the next command line options should be used:

* `--p=jq` or do not use `--p` (default behavior) — [JSON](https://github.com/timo/json_fast) processor;
* `--p=yq` — [YAML](https://github.com/Leont/yamlish) processor.

### Versions consistency

To verify the version [consistency](https://gitlab.com/pheix-research/talks/-/tree/main/pre-RC2#version-control-consistency-in-git-commit-message-and-pheixmodelversion) on commit, the next command line options should be used:

* `--g` — path to git repo with version at latest commit in format `%0d.%0d.%0d`;
* `--v` — current version to commit (in format `%0d.%0d.%0d` as well).

```
trove-cli -c --g=~/git/raku-foo-bar --v=1.0.0
```

### Target configuration file

By default the next configuration targets are used:

* JSON — `./x/trove-configs/test.conf.json`;
* YAML — `./x/trove-configs/test.conf.yaml`.

These paths are used to test `Trove` itself with:

    cd ~/git/raku-trove && bin/trove-cli -c && bin/trove-cli -c --p=yq

To use another configuration file you have to specify it via `--f` option:

    trove-cli --f=/tmp/custom.jq.conf

### First stage logging policy

`trove-cli` is obviously used to test Pheix. First Pheix testing stage checks `www/user.rakumod` script with:

```bash
    raku $WWW/user.raku --mode=test # WWW == './www'
```

This command prints nothing to standard output and eventually nothing is needed to be saved to log file. By default first stage output is ignored. But if you use Pheix Tests tool to test some other module or application, i might be handy to force save first stage output. This is done by `-l` command line argument:

    trove-cli --f=/tmp/custom.jq.conf -l

In case the stage with blank output is not skipped it's taken into coverage scope but marked as `WARN` in `trove-cli` output:

```bash
01. Testing ./www/user.raku                                [ WARN ]
02. Testing ./t/cgi/cgi_post_test.sh                       [ 6% covered ]
...
```

### Origin repository

By default origin repository is set up to `git@github.com:pheix/raku-trove.git` and you can change it to any value you prefer by `-o` argument:

    trove-cli --f=/tmp/custom.jq.conf --o=git@gitlab.com:pheix/net-ethereum-perl6.git

## Test configuration files — JSON & YAML

### Configuration file sections

* `target` — description of test target;
* `explore` — explore file system and build test plan with stages automatically;
* `stages` — list of the test stages.

#### Explore

`explore` section is used to build test plan with test stages automatically. Consider a Perl module with some tests within `./t` folder — two options for you: add every unit test as stage manually or just configure some universal stage setup under the `explore` section.

```yaml
target: Trivial one-liner test
explore:
  base: ./t
  pattern: (<[0..9]>+)\.t
  interpreter: perl
  recursive: 1
```

* `base` — relative or absolute base path where `Trove` will find unit test;
* `pattern` — Raku regular expression that will be used for matching;
* `interpreter` — default interpreter to run the unit tests;
* `recursive` — try to traverse sub folders recursively.

By default `interpreter` is `raku`, and `recursive` is disabled.

#### Stage and substage

* `test` — test command to execute;
* `args` — if command uses environment variables, they should be in `test` command line (`%SOMEVAR%` for `jq` and `$SOMEVAR` for `yq`) and in `args` list as `SOMEVAR` (no `$` or `%` chars);
* `environment` — command to set up environmental variables for the stage, e.g. `export HTTP_REFERER=//foo.bar` or whatever else, please keep in mind — `environment` is defines as list, but actually only first element of this list is used, so no matter how many command you set up there, only the first one will be used;
* `cleanup` — command to clean up environmental variables for the stage, the same restrictions are actual here;
* `substages` — list of the test substages;

#### Mix it up!

You can mix `explore` and `stages` sections to flexibly cover some edge test cases like:

```yaml
target: Trivial one-liner test
explore:
  base: ./t
  pattern: (0 <[0..9]> ** 1..1)\.t
stages:
  - test: 'raku ./t/11.t $INPUT'
    args:
      - INPUT
```

In this sample `Trove` will automatically add stages for `./t/00.t` ... `./t/09.t` unit tests and will run one manually added stage with additional input argument from environmental variable for `./t/11.t` unit test.

### Trivial test configuration example

Trivial multi-interpreter one-liner test [configuration file](https://github.com/pheix/raku-trove/blob/main/x/trove-configs/test.conf.yaml.explorer) is included to `Trove`:

```yml
target: Trivial one-liner test
stages:
  - test: raku  -eok(1); -MTest
  - test: perl6 -eis($CONSTANT,2); -MTest
    args:
      - CONSTANT
  - test: perl  -eok(3);done_testing; -MTest::More
```

Test command to be executed:

    CONSTANT=2 && trove-cli --f=/home/pheix/git/raku-trove/x/trove-configs/test.conf.yaml.explorer --p=yq -c

### Pheix test suite configuration files

Pheix test suite configuration files have a full set of features we talked above: `explore`, `stages`, `subtages`, environmental variables export, setup and clean up. These files could be used as basic examples to create test configuration for yet another module or application, no matter — Raku, Perl or something else.

Sample [snippet](https://gitlab.com/pheix/dcms-raku/-/blob/develop/run-tests.conf.yml) from `run-tests.conf.yml`:

```yaml
target: Pheix test suite
explore:
  base: ./t
  pattern: (<[23]> ** 1..1 <[0..9]> ** 1..1)|(<[01]> ** 1..1 <[234569]> ** 1..1)|('07'|'08'|'10')<[a..z-]>+\.t
  interpreter: raku
stages:
  - test: 'raku $WWW/user.raku --mode=test'
    args:
      - WWW
  - test: ./t/cgi/cgi_post_test.sh
    substages:
      - test: raku ./t/00-november.t
  ...
  - test: 'raku ./t/11-version.t $GITVER $CURRVER'
    args:
      - GITVER
      - CURRVER
  ...
  - test: raku ./t/17-headers-proto-sn.t
    environment:
      - 'export SERVER_NAME=https://foo.bar'
    cleanup:
      - unset SERVER_NAME
    substages:
      - test: raku ./t/17-headers-proto-sn.t
        environment:
          - export SERVER_NAME=//foo.bar/
        cleanup:
          - unset SERVER_NAME
  - test: raku ./t/18-headers-proto.t
    substages:
      - test: raku ./t/18-headers-proto.t
        environment:
          - 'export HTTP_REFERER=https://foo.bar'
        cleanup:
          - unset HTTP_REFERER
  ...
```

## Test coverage management

### Gitlab

Coverage percentage in Gitlab is retrieved from job's standard output: while your tests are running, you have to print actual test progress in percents to console (`STDOUT`). Output log is parsed by runner on job finish, the matching patterns [should be set up](https://docs.gitlab.com/ee/ci/pipelines/settings.html#add-test-coverage-results-using-project-settings-removed) in `.gitlab-ci.yml` — CI/CD configuration file.

Consider trivial test configuration example from the [section above](#trivial-test-configuration-example), the standard output is:

```
01. Running -eok(1,'true');                              [ 33% covered ]
02. Running -eis(2,2,'2=2');                             [ 66% covered ]
03. Running -eok(3,'perl5');done_testing;                [ 100% covered ]
```

Matching pattern in `.gitlab-ci.yml` is set up:

```yaml
...
trivial-test:
  stage: trivial-test-stable
  coverage: '/(\d+)% covered/'
  ...
```

### Coveralls

#### Basics

[Coveralls](https://coveralls.io/) is a web service that allows users to track the code coverage of their application over time in order to optimize the effectiveness of their unit tests. `Trove` test tool includes Coveralls integration via [API](https://docs.coveralls.io/api-reference).

API reference is quite clear — the generic objects are `job` and `source_file`. Array of source files should be included to the job:

```javascript
{
  "service_job_id": "1234567890",
  "service_name": "Trove::Coveralls",
  "source_files": [
    {
      "name": "foo.raku",
      "source_digest": "3d2252fe32ac75568ea9fcc5b982f4a574d1ceee75f7ac0dfc3435afb3cfdd14",
      "coverage": [null, 1, null]
    },
    {
      "name": "bar.raku",
      "source_digest": "b2a00a5bf5afba881bf98cc992065e70810fb7856ee19f0cfb4109ae7b109f3f",
      "coverage": [null, 1, 4, null]
    }
  ]
}
```

In example above we covered `foo.raku` and `bar.raku` by our tests. File `foo.raku` has 3 lines of source code and only line no.2 is covered.  File `bar.raku` has 4 lines of source code, lines no.2 and no.3 are covered, 2nd just once, 3rd — four times.

#### Test suite integration

We assume full coverage for some software part if its unit test is passed. Obviously this part is presented by its unit tests and `source_files` section in Coveralls request looks like:

```javascript
...
"source_files": [
    {
      "name": "./t/01.t",
      "source_digest": "be4b2d7decf802cbd3c1bd399c03982dcca074104197426c34181266fde7d942",
      "coverage": [ 1 ]
    },
    {
      "name": "./t/02.t",
      "source_digest": "2d8cecc2fc198220e985eed304962961b28a1ac2b83640e09c280eaac801b4cd",
      "coverage": [ 1 ]
    }
  ]
...
```

We consider no lines to be covered, so it's enough to set `[ 1 ]` to `coverage` member.

Besides `source_files` member we have to set up a `git` [member](https://docs.coveralls.io/api-reference#arguments) as well. It's pointed as optional, but your build reports on Coveralls side will look anonymous without git details (commit, branch, message and others).

#### Setup automatic coverage upload

You have to set up your test environment to send coverage to Coveralls service automatically. Initially `Trove` was a simple bash script targeted to GitLab and relied on the next environmental variables:

* `CI_JOB_ID` - [predefined](https://docs.gitlab.com/ee/ci/variables/predefined_variables.html) GitLab CI job identifier, actually `CI_JOB_ID` can be any integer value you prefer — just `date +%s` or something dummy like `0`;
* `COVERALLSTOKEN` - Coveralls secret [repository token](https://docs.coveralls.io/api-introduction).

Sample `Trove` run with the subsequent test coverage upload to Coveralls:

```bash
CI_JOB_ID=`date +%s` COVERALLSTOKEN=<coveralls-secret-repo-token> RAKULIB=./lib trove-cli -c --f=`pwd`/x/trove-configs/test.conf.yaml.explore --p=yq
```

If you are familiar with GitLab, you can check [Pheix pipelines](https://gitlab.com/pheix/dcms-raku/-/pipelines). `Trove` is used there as a primary test tool since the late November 2022. GitLab sets up `CI_JOB_ID` automatically and `COVERALLSTOKEN` is configured manually with CI/CD [protected variables](https://docs.gitlab.com/ee/ci/variables/#add-a-cicd-variable-to-a-project). So, usage with GitLab is quite transparent/friendly:

![Gitlab CI/CD protected variables Pheix setup](https://user-images.githubusercontent.com/6272762/210155017-1914d50d-f46b-49ac-8334-f8e749c23faa.png)

## Log test session

While testing `trove-cli` does not output any TAP messages to standard output. Consider trivial multi-interpreter one-liner test again:

```
01. Running -eok(1,'true');                              [ 33% covered ]
02. Running -eis(2,2,'2=2');                             [ 66% covered ]
03. Running -eok(3,'perl5');done_testing;                [ 100% covered ]
```

On the background `trove-cli` saves the full log with extended test details. Log file is save to current (work) directory and has the next file name format: `testreport.*.log`, where `*` is test run date, for example: `testreport.2022-10-18_23-21-12.log`.

Test command to be executed:

```bash
cd ~/git/raku-trove && CONSTANT=2 bin/trove-cli --f=`pwd`/x/trove-configs/tests.conf.yml.oneliner --p=yq -c -l
```

Log file `testreport.*.log` content is:

```
----------- STAGE no.1 -----------
ok 1 - true

----------- STAGE no.2 -----------
ok 1 - 2=2

----------- STAGE no.3 -----------
ok 1 - perl5
1..1
```

## Integration with CI/CD environments

### github.com

Consider module `Acme::Insult::Lala`, to integrate `Trove` to [Github actions](https://github.com/features/actions) CI/CD environment we have to create `.github/workflows/pheix-test-suite.yml` with the next instructions:

```yml
name: CI

on:
  push:
    branches: [ master ]
  pull_request:
    branches: [ master ]

jobs:
  build:
    runs-on: ubuntu-latest

    container:
      image: rakudo-star:latest

    steps:
      - uses: actions/checkout@v2
      - name: Perform test with Pheix test suite
        run: |
          zef install Trove
          ln -s `pwd` /tmp/Acme-Insult-Lala
          cd /tmp/Acme-Insult-Lala && RAKULIB=lib trove-cli --f=/tmp/Acme-Insult-Lala/.run-tests.conf.yml --p=yq -l -c
          cat `ls | grep "testreport"`
```

CI/CD magic happens at `run` instruction, let's explain it line by line:

1. `zef install Trove` — install `Trove` test tool;
2. `ln -s ...` — creating the module path consistent with `.run-tests.conf.yml`;
3. `cd /tmp/Acme-Insult-Lala && ...` — run the tests;
4. `cat ...` — print test log.

Check the job: https://github.com/pheix/Acme-Insult-Lala/actions/runs/3621090976/jobs/6104091041

<img src=https://gitlab.com/pheix-research/talks/-/raw/main/advent/assets/2022/ci-cd/github.png>

### gitlab.com

Let's integrate module perl5 module `Acme` with `Trove` to [Gitlab CI/CD](https://docs.gitlab.com/ee/ci/quick_start/) environment — we have to create `.gitlab-ci.yml` with the next instructions:

```yml
image: rakudo-star:latest

before_script:
  - apt update && apt -y install libspiffy-perl
  - zef install Trove
  - ln -s `pwd` /tmp/Acme-perl5
test:
  script:
    - cd /tmp/Acme-perl5 && PERL5LIB=lib trove-cli --f=/tmp/Acme-perl5/.run-tests.conf.yml --p=yq -l -c
    - cat `ls | grep "testreport"`
  only:
    - main
```

On Gitlab CI/CD magic happens in `before_script` and `test/script` instructions. Behavior is exactly the same as it was in `run` instruction for Github action.

Check the job: https://gitlab.com/pheix-research/perl-acme/-/jobs/3424335705

<img src=https://gitlab.com/pheix-research/talks/-/raw/main/advent/assets/2022/ci-cd/gitlab.png>

## License

This is free and opensource software, so you can redistribute it and/or modify it under the terms of the [The Artistic License 2.0](https://opensource.org/licenses/Artistic-2.0).

## Author

Please contact me via [LinkedIn](https://www.linkedin.com/in/knarkhov/) or [Twitter](https://twitter.com/CondemnedCell). Your feedback is welcome at [narkhov.pro](https://narkhov.pro/contact-information.html).

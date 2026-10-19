# CLI argument errors

Verify the message and process status emitted by the executable. Current CLI errors use stdout.

## Usage errors: status 3

Unknown options, missing values and malformed codes are usage errors.

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --unknown
@STDOUT
Unknown option: --unknown
@STDERR (empty)
[3]

$ moonx moonbit-community/bashcheck --include wat
@STDOUT
Invalid number: wat
@STDERR (empty)
[3]

$ moonx moonbit-community/bashcheck -iSCwat
@STDOUT
Invalid number: SCwat
@STDERR (empty)
[3]

$ moonx moonbit-community/bashcheck --format
@STDOUT
Missing value for --format
@STDERR (empty)
[3]

$ moonx moonbit-community/bashcheck -s
@STDOUT
Missing value for -s
@STDERR (empty)
[3]

$ moonx moonbit-community/bashcheck --extended-analysis maybe
@STDOUT
Invalid boolean, expected true/false: maybe
@STDERR (empty)
[3]

$ moonx moonbit-community/bashcheck --wiki-link-count wat
@STDOUT
Invalid number: wat
@STDERR (empty)
[3]
```

## Unsupported values: status 4

Syntactically valid unsupported settings have a distinct exit code.

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --severity bogus
@STDOUT
Unknown value for --severity. Valid options are: error, warning, info, style
@STDERR (empty)
[4]

$ moonx moonbit-community/bashcheck --shell bogus
@STDOUT
Unknown shell: bogus
@STDERR (empty)
[4]

$ moonx moonbit-community/bashcheck --color=bogus
@STDOUT
Unknown value for --color. Valid options are: auto, always, never
@STDERR (empty)
[4]

$ moonx moonbit-community/bashcheck --format bogus
@STDOUT
Unknown format bogus
Supported formats:
  checkstyle
  diff
  gcc
  json
  json1
  quiet
  tty
@STDERR (empty)
[4]
```

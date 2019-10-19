# tabula-mark

A simple Command-Line Interface for marking scripts with Tabula.

This is only suitable for assignments which:

* Have single-file submissions (eg. one PDF);
* Have text-only feedback;
* Are graded on the 100-point scale.

## Installation

1. Install `stack`.
1. `git clone dixonary/tabula-mark`.
1. `cd tabula-mark && stack build --copy-bins`. (This should put `mark` on your `$PATH` by default.)

## Usage

1. Make sure your `$EDITOR` environment variable is set to your preferred terminal text editor.
1. Set the `$TABULA_UID` and `$TABULA_PASS` environment variables to your login details for Tabula. This should be an external user account created for the purpose.
1. Note the assignment ID for the assignment you wish to mark. This will be the UUID in the URL of the assignment page as viewed online. Your EUA must have at least assistant permissions on the assignment.
1. Create a working directory for your marking session and enter it.
1. Create a file representing the feedback template and save it as `template` (no extension).
1. Run `mark` and follow the interactive instructions.

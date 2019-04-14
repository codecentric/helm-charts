# Contributing Guidelines

Contributions are welcome via GitHub pull requests.
This document outlines the process to help get your contribution accepted.

## Sign off Your Work

The Developer Certificate of Origin (DCO) is a lightweight way for contributors to certify that they wrote or otherwise have the right to submit the code they are contributing to the project.
Here is the full text of the [DCO](http://developercertificate.org/):

```
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.
1 Letterman Drive
Suite D4700
San Francisco, CA, 94129

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.


Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

Contributors must sign-off that they adhere to these requirements by adding a `Signed-off-by` line to commit messages.

```
This is my commit message

Signed-off-by: Random J Developer <random@developer.example.org>
```

Git has a `-s` command line option to append this automatically to your commit message:

```console
$ git commit -s -m 'This is my commit message'
```

## How to Contribute

1. Fork this repository, develop, and test your changes.
1. Remember to sign off your commits as described above.
1. Submit a pull request.

***NOTE***: In order to make testing and merging of PRs easier, please submit changes to multiple charts in separate PRs.

### Technical Requirements

* Must pass linting and installing with the [chart-testing](https://github.com/helm/chart-testing) tool
* Must follow [best practices](https://github.com/helm/helm/tree/master/docs/chart_best_practices) and [review guidelines](https://github.com/helm/charts/blob/master/REVIEW_GUIDELINES.md)

### Documentation Requirements

* A chart's `README.md` must include configuration options
* A chart's `NOTES.txt` must include relevant post-installation information

### Merge Approval and Release Process

* Must pass DCO check
* Must pass CI jobs for linting and installing changed charts
* Any change to a chart requires a version bump following [semver](https://semver.org/) principles

Once changes have been merged, the release job will automatically run to package and release changed charts.

import os
import subprocess
import sys
from enum import Enum

MAJOR_KEYWORDS = ["breaking", "major"]
MINOR_KEYWORDS = ["feat", "feature", "minor"]
SKIP_BUMP_KEYWORDS = ["chore", "Bump version"]


class UpgradeType(Enum):
    NONE = 'none'
    PATCH = 'patch'
    MINOR = 'minor'
    MAJOR = 'major'


upgrade_type = UpgradeType.NONE


def handle_subprocess_error(subprocess_result, error_message):
    if subprocess_result.returncode != 0:
        print(error_message)
        print(f"Return code {subprocess_result.returncode}")
        print("STDERR:")
        print(str(subprocess_result.stderr, "UTF-8"))
        print("STDOUT:")
        print(str(subprocess_result.stdout, "UTF-8"))
        exit(1)


if __name__ == "__main__":
    chart_name = os.getenv("CHART_NAME")
    print(f"Bumping chart version for: {chart_name}")

    from_commit_hash_process = subprocess.run(f"git rev-parse ':/^Bump {chart_name} chart version:'",
                                              shell=True,
                                              capture_output=True)
    if from_commit_hash_process.returncode != 0:
        print(str(from_commit_hash_process.stderr, 'UTF-8'))
        print("Did not find the last bump commit. Assuming PATCH update now")
        upgrade_type = UpgradeType.PATCH
    else:
        last_bump_commit_hash = str(from_commit_hash_process.stdout, 'UTF-8').strip()
        get_commits_process = subprocess.run(
            f"git log --pretty=format:%s '{last_bump_commit_hash}..HEAD' .",
            cwd=f"./charts/{chart_name}",
            shell=True,
            capture_output=True)

        handle_subprocess_error(get_commits_process, "Obtaining the commits since the last tag was not successful.")

        print("inspected the following commit messages:")
        commit_messages = str(get_commits_process.stdout, "UTF-8").strip().split("\n")
        print(commit_messages)
        for line in commit_messages:
            if len(line) == 0:
                continue

            if any(x.lower() in line.lower() for x in MAJOR_KEYWORDS):
                upgrade_type = UpgradeType.MAJOR
                break
            elif any(x.lower() in line.lower() for x in MINOR_KEYWORDS):
                upgrade_type = UpgradeType.MINOR
            elif upgrade_type != UpgradeType.MINOR and not any(x.lower() in line.lower() for x in SKIP_BUMP_KEYWORDS):
                upgrade_type = UpgradeType.PATCH

    if upgrade_type == UpgradeType.NONE:
        print("No need for a version bump detected")
        print("::set-output name=changes::false")
        exit(0)

    print(f"Doing upgrade of type {upgrade_type.value} now")

    bumpver_process = subprocess.run(f"bump2version {upgrade_type.value}",
                                     shell=True,
                                     cwd=f"./charts/{chart_name}",
                                     capture_output=True)
    handle_subprocess_error(bumpver_process, "Could not execute version bump")

    print("::set-output name=changes::true")

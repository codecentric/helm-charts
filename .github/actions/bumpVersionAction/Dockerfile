# Container image that runs your code
FROM python:alpine

WORKDIR /github/workspace

RUN pip install bump2version && apk add git

COPY bump-version.py /bump-version.py

# The git add safe.directory $(pwd) is needed because since CVE-2022-24765 git checks the owernership of the processed repos
CMD sh -c 'git config --global --add safe.directory $(pwd) && exec python /bump-version.py'

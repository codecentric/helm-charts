# Container image that runs your code
FROM python:alpine

RUN pip install bump2version && apk add git

COPY bump-version.py /bump-version.py

ENTRYPOINT ["python" ,"/bump-version.py"]

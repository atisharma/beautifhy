
FROM        docker.io/library/python:3-slim

ADD . /opt/hylang/beautifhy
RUN pip3 install -e /opt/hylang/beautifhy

CMD ["hy-repl"]

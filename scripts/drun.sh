#!/bin/bash
if ! systemctl status docker>/dev/null; then systemctl start docker.socket; fi
docker run --rm -it -v $PWD:/pwd "$@"

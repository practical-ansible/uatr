#!/usr/bin/env bash

loc="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

cd $loc
docker stop hosting-test 2> /dev/null
docker rm hosting-test 2> /dev/null
docker build -t hosting-test hosting
docker run -v /var/run/docker.sock:/var/run/docker.sock -d -P --rm --name hosting-test hosting-test

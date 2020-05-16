#!/usr/bin/env bash

docker stop hosting-test 2> /dev/null
docker rm hosting-test 2> /dev/null
docker build -t hosting-test hosting
docker run -v /var/run/docker.sock:/var/run/docker.sock -d -P --rm --name hosting-test hosting-test

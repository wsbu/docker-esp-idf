#!/bin/sh

docker build --no-cache -t wsbu/esp-idf:v4.4.2000 --build-arg SSH_KEY="`cat ~/.ssh/bitbucket_npw`" .
docker login
docker push wsbu/esp-idf:v4.4.2000
docker push wsbu/esp-idf:v4.4.latest

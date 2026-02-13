#!/bin/sh

echo
echo "Building..."

docker compose build --pull

if [ "$?" -ne "0" ]; then
  exit $?
fi

docker login docker.c7a.ca

if [ $? -ne 0 ]; then
  echo 
  echo "Error logging into the c7a Docker registry."
  exit 1
fi

BRANCH=`git rev-parse --abbrev-ref HEAD`

if [ "${BRANCH}" = "main" ]; then
  IMAGEEXT="";
else
  IMAGEEXT="-${BRANCH}"
fi

TAG=`date -u +"%Y%m%d%H%M%S"`

echo

echo "Tagging crkn_canadiana_blacklight-web$IMAGEEXT:latest as docker.c7a.ca/crkn_canadiana_blacklight-web$IMAGEEXT:$TAG"

docker tag crkn_canadiana_blacklight-web:latest docker.c7a.ca/crkn_canadiana_blacklight-web$IMAGEEXT:$TAG

if [ $? -ne 0 ]; then
  exit $?
fi

echo
echo "Pushing docker.c7a.ca/crkn_canadiana_blacklight-web$IMAGEEXT:$TAG"

docker push docker.c7a.ca/crkn_canadiana_blacklight-web$IMAGEEXT:$TAG

if [ "$?" -ne "0" ]; then
  exit $?
fi

echo
echo "Push sucessful. Create a new issue at:"
echo
echo "https://github.com/crkn-rcdr/Systems-Administration/issues/new?title=New+crkn_canadiana_blacklight-web+image:+%60docker.c7a.ca/crkn_canadiana_blacklight-web$IMAGEEXT:$TAG%60&body=Please+describe+the+changes+in+this+update%2e"
echo
echo "to alert the systems team. Don't forget to describe what's new!"
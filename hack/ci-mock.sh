#!/usr/bin/env bash

project=$(gcloud config get-value core/project)
repository="podinfo"
branch="master"
version=""
commit=$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1 | awk '{print tolower($0)}')

while getopts :r:b:v: o; do
    case "${o}" in
        r)
            repository=${OPTARG}
            ;;
        b)
            branch=${OPTARG}
            ;;
        v)
            version=${OPTARG}
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${version}" ]; then
    image="${project}/${repository}:${branch}-${commit}"
    version="0.4.0"
else
    image="${project}/${repository}:${version}"
fi

echo ">>>> Building image ${image} <<<<"

echo "docker build --build-arg GITCOMMIT=${commit} --build-arg VERSION=${version} -t ${image} -f Dockerfile.ci ."
docker build --build-arg GITCOMMIT=${commit} --build-arg VERSION=${version} -t ${image} -f Dockerfile.ci .

gcloud docker -- push gcr.io/${image}

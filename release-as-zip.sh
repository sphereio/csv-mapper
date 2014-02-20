#!/bin/bash

set -e

BRANCH_NAME='latest'

set +e
git branch -D ${BRANCH_NAME}
set -e

rm -rf lib
rm -rf node_modules

npm version patch
git branch ${BRANCH_NAME}
git checkout ${BRANCH_NAME}

npm install
grunt build
rm -rf node_modules
npm install --production
git add -f lib/
git add -f node_modules/
git commit -m "Update generated code and runtime dependencies."
git push --force origin ${BRANCH_NAME}

git checkout master

VERSION=$(cat package.json | jq --raw-output .version)
git push origin "v${VERSION}"
npm version patch
npm install

if [ -e tmp ]; then
    rm -rf tmp
fi
mkdir tmp
cd tmp
curl -L https://github.com/sphereio/sphere-product-mapper/archive/latest.zip -o latest.zip
unzip latest.zip
cd sphere-product-mapper-latest/
node lib/run

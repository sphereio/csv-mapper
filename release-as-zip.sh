#!/bin/bash

set -e

rm -rf lib

BRANCH_NAME='latest'

npm version patch
git checkout ${BRANCH_NAME}
git merge master

grunt build
git add -f lib/
libs=$(cat package.json | jq -r '.dependencies' | grep ':' | cut -d: -f1 | tr -d " " | tr -d '"')
for lib in $libs; do
    git add -f node_modules/$lib
done
git commit -m "Update generated code and runtime dependencies."
git push origin ${BRANCH_NAME}

git checkout master
npm version patch
git push origin master

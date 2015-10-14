#!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

# Add changes to git.
git add -A

# Build the project.
hugo --verbose

# Commit changes.
msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "Updating site" && git push origin master

git subtree push --prefix=public git@github.com:asya999/asya999.github.io.git master

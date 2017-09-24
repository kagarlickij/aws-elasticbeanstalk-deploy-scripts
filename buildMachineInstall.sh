#!/bin/bash
# By Dmitriy Kagarlickij
# dmitriy@kagarlickij.com

add-apt-repository ppa:git-core/ppa -y
apt-get update
apt-get install git -y

ssh-keyscan github.com >> ~/.ssh/known_hosts
git clone https://github.com/kagarlickijd/meteorapp-deploy-scripts.git /deploy-scripts --quiet

echo .gitignore >> /deploy-scripts/.git/info/exclude

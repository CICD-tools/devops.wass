#!/bin/sh
repo_dir=$(dirname $0)
cp -i "${repo_dir}/#githooks"/* "${repo_dir}/.git/hooks"
chmod ug+x "${repo_dir}/.git/hooks"/*

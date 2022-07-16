#!/bin/sh

asdf current | grep -qiv "^no plugin"

if [ $? -ne 0 ]; then
    asdf plugin add lane https://github.com/codereaper/asdf-lane.git
    asdf install
fi
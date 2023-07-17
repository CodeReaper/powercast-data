#!/bin/sh

if ! asdf current | grep -qiv "^no plugin"; then
    asdf plugin add lane https://github.com/codereaper/asdf-lane.git
    asdf install
fi

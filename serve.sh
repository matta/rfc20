#!/usr/bin/env bash
nix-shell --run "hugo serve --buildDrafts --buildFuture --disableFastRender --navigateToChanged"

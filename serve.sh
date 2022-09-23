#!/usr/bin/env bash
nix-shell --run "HUGO_MODULE_REPLACEMENTS='github.com/matta/rfc20-theme -> ../../rfc20-theme' hugo serve --buildDrafts --buildFuture --disableFastRender --navigateToChanged"

#!/bin/bash

$(mops toolchain bin moc) src/main.mo -o out.wasm -c --debug --public-metadata candid:service --public-metadata candid:args $(mops sources)
sha256sum out.wasm

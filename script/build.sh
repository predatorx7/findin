#!/usr/bin/env bash

mkdir -p build

EXE_NAME=findin
EXE_PATH=build/$EXE_NAME
dart compile exe -o $EXE_PATH ./bin/findin.dart

mkdir -p ~/.local/bin

INSTALLATION_DIR=~/.local/bin
INSTALLATION_LOCATION=$INSTALLATION_DIR/$EXE_NAME
mv $EXE_PATH $INSTALLATION_LOCATION
echo Installed at: $INSTALLATION_LOCATION

#!/bin/sh -e
DEVICE=$1
[ "$DEVICE" = "" ] && DEVICE=fenix3_hr

RESOURCE_PATH=$(find . -path './resources*.xml' | xargs | tr ' ' ':')
monkeyc -o myapp.prg -d $DEVICE -m manifest.xml -z $RESOURCE_PATH source/*.mc -y ~/workspace/fenix3/developer_key.der

#!/bin/sh
if [ $# -ne 0 ]
then
  exec "$@"
else
  exec /usr/bin/lsyncd /lsyncd/config.lua
fi

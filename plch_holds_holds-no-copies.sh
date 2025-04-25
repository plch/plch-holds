#!/bin/bash
cd "$(dirname "$0")"
venv/bin/python plch_holds.py holds-no-copies >> log.txt &
wait

#!/bin/bash
cd "$(dirname "$0")"
venv/bin/python plch_holds.py system-wide >> log.txt &
wait

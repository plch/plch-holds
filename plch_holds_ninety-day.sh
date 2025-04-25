#!/bin/bash
cd "$(dirname "$0")"
venv/bin/python plch_holds.py ninety-day >> log.txt &
wait

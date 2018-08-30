#!/bin/sh
#
# Show all TODO, FIXME and XXX occurences in the sources, with three lines of
# context after each match

grep -n -A3 'TODO\|FIXME\|XXX' `find src -name '*.s' -o -name '*.inc' | sort`


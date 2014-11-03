#!/bin/bash
section_name=$(echo '/dev/null' |  sed 's/\//\\\//g')
echo section_name is \"$section_name\"
cat a.ini <(echo '[something that marks the end of the file]') | egrep -v '^ *[;#]'  | sed -n '/^\['${section_name}']/,/^\[/p' | head --lines=-1 | sed 's/\[\(.*\)\]/section=\1/' | sed 's/\([^ ]*\) *= *\(.*\)/\1=(\2)/' > b.tmp

{ while read line;
    do
    echo "Got line \"$line\""
    eval $line
    echo "this[0] is ${this[0]}"
    echo "this[1] is ${this[1]}"
    echo "this[2] is ${this[2]}"
    echo "this[3] is ${this[3]}"
    echo "this[4] is ${this[4]}"
    done;
} < b.tmp

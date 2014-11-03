checkit()
{
    local status
    echo "$1" | egrep -q "^[0-9]*(:[0-5][0-9])?$"
    status=$?
    #echo $test_num: status is $status
    if [[ $status -eq $2 ]]
    then
        echo ok $test_num
    else
        echo not ok $test_num - fail for \"$1\"
    fi
    test_num=$(( test_num + 1 ))
}

check_sed()
{
    local hr
    local mn
    eval `echo $1 | sed -ne 's/\([0-9]*\):\{0,1\}\([0-5][0-9]\)\{0,1\}/hr=\"\1\";mn=\"\2\"/p'`
    if [ "$hr" == "$2" -a "$mn" == "$3" ]
    then
        echo ok $test_num
        echo \# total_min is: $(( hr * 60 + mn ))
    else
        echo not ok $test_num - fail for \"$1\" "(hr: \"$hr\" mn: \"$mn\")"
    fi
    test_num=$(( test_num + 1 ))
}

DEBUG()
{
#    return 0
    return 1
}

extract_def()
{
    local defname="$1"
    local script="$2"
    local default="${3:-}"
    local badvalue="${4:-}"

    DEBUG && echo extract_def: checking for $defname >&2
    arydef=()                   # Clear any previous values
    while read -r; do
        DEBUG && echo "extract_def:    read $REPLY" >&2
        arydef+=("$REPLY")
    done < <(egrep -v '^( *#|$)' "$script" | sed -ne '/\['"$defname"'\]/,/\(^\[\)/p' | sed -ne '/\['"$defname"'\]/,/(^[ \t]*$)/p' | egrep -v '^(\[|[ \t]*$)' | sed -e 's/^[ \t]*//')
    DEBUG && echo arydef is "${arydef[@]}" sizeof arydef is: ${#arydef[@]} >&2
    if [[ ${#arydef[@]} -eq 0 ]]
    then
        DEBUG && echo default is: \"$default\" >&2
        if [[ -n "$default" ]]
        then
            arydef=("$default")
            return 0
        else
            # No default => error if no defname present
            echo "No configuration value found for \"$defname\"" >&2
            return 1
        fi
    else
        # We got something, but was it the wrong answer?
        if [[ ${arydef[0]} = $badvalue ]]
        then
            echo Please edit the configuration file \"$script\" so that the values match your system
            return 1
        fi
    fi
    return 0
}

check_extract_def()
{
    local result_index="$1"; shift
    local result_value="$1"; shift
    local expected_status="$1"; shift
    local defname="$1"; shift
    local default="$1"; shift
    local badvalue="$1"; shift
    local tmpnam=`mktemp /tmp/tmp.XXXXXXXX`
    local value
    local i
    for i in "$@"
    do
        echo "$i" >> $tmpnam
    done
    DEBUG && echo ""
    DEBUG && echo result_index is \""$result_index"\" result_value is \""$result_value"\"
    DEBUG && echo expected_status is \""$expected_status"\" defname is \""$defname"\" default is \""$default"\" badvalue is \""$badvalue"\"

    declare -a arydef
    extract_def "$defname" "$tmpnam" "$default" "$badvalue"
    e_d_status=$?
    value="${arydef[$result_index]}"

    DEBUG && echo "returned status is: $e_d_status" >&2
    # If the returned status is OK (and that's what we wanted)...
    if [[ $expected_status -eq 0 && $e_d_status -eq 0 ]]
    then
        if [ "$value" == "$result_value" ]
        then
            echo ok $test_num
        else
            echo not ok $test_num - Got "${arydef[@]}"
        fi
    elif [[ $expected_status -eq $e_d_status ]]
    then
        echo ok $test_num
    else
        echo not ok $test_num - Got status $e_d_status; wanted $expected_status
    fi

    rm -f $tmpnam
    test_num=$(( test_num + 1 ))
}

test_num=1

checkit 44 0                    # 1
checkit 55: 1                   # 2
checkit :33 0                   # 3
checkit 4:33 0                  # 4
checkit -d 1                    # 5
checkit 42:11 0                 # 6
checkit gabble 1                # 7
checkit 3:88 1                  # 8

check_sed 44:33 44 33           # 9
check_sed 44 44                 # 10
check_sed :33 "" 33             # 11

# Make sure a regular definition works
check_extract_def 0 foo 0 source '' '' "[source]" "foo" "# end" # 12
# Make sure a definition name can have spaces
check_extract_def 0 foo 0 'source with spaces' '' '' "[source with spaces]" "foo" "# end" # 13

# Half-assed checks of array functionality
# Check array values at indices 0, 1, and 2
check_extract_def 0 foo 0 source '' '' "[source]" "foo" "boo" "hoo" "# end"
check_extract_def 1 boo 0 source '' '' "[source]" "foo" "boo" "hoo" "# end"
check_extract_def 2 hoo 0 source '' '' "[source]" "foo" "boo" "hoo" "# end"

# check allowed formatting
#     comments are allowed and start with a #
check_extract_def 0 foo 0 source '' '' "#Comment1" "[source]" "#internal comment" "foo" "boo" "hoo" "# end"
#     internal blank line
check_extract_def 2 hoo 0 source '' '' "#Comment1" "[source]" "#internal comment" "foo" "" "boo" "hoo" "# end"

# defaults
# if a default is given but there is a definition, return the definition
check_extract_def 0 foo 0 source 'gubber' '' "[source]" "foo" "# end"
# extract_def will return default value if 1) the extraction yields nothing, and 2) default value is present
check_extract_def 0 gubber 0 source 'gubber' '' "[source]" "# end"
check_extract_def 0 gubber 0 source 'gubber' '' "[source]"
check_extract_def 0 gubber 0 source 'gubber' '' "[something_else]" "# end"
# Make sure a default value can have spaces
check_extract_def 0 'default with spaces' 0 source 'default with spaces' '' "[something_else]" "# end"

# If no default is given, and no definition is present, that is an error
check_extract_def 0 foo 1 source '' '' "[source]" "# end"

# If there is a value, but it was from the default template, the user hasn't edited the config file
check_extract_def 0 foo 1 source '' '/argle/bargle' "[source]" "/argle/bargle" "# end"

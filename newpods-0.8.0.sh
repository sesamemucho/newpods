#!/bin/bash --
#
# Execute this with a '.', so the history commands work
#
#       Copyright 2009 Bob Forgey <rforgey.newpods@grumpydogconsulting.com>
#
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 3 of the License, or
#       (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#       MA 02110-1301, USA.

# Give the user something to look at. Nothing will come out on stdout until
# the subshell finishes.
# But don't do it if we have been given a '-Q' flag
if [[ $(getopt dhmvqQ $*) != *-Q* ]]
then
    cat - <<EOF
newpods Copyright (C) 2009 Bob Forgey
This program comes with ABSOLUTELY NO WARRANTY
This is free software, and you are welcome to redistribute it
under certain conditions; for details see the file COPYING or
<http://www.gnu.org/licenses/>.

Searching for files...
EOF
fi

(
if [[ $BASH_SOURCE == $0 ]]; then
    byebye='exit'
    is_script=1
    is_sourced=0
else
    byebye='return'
    is_script=0
    is_sourced=1
fi

# Portability
systype="none"
if uname -a | grep -i bsd >& /dev/null; then
    f_info="-exec  stat -f \"%Fc %Sc %SN\" {} \;"
    f_info_trim=22
    systype="bsd"
elif uname -a | grep -i darwin >& /dev/null; then
    f_info="-exec  stat -f \"%Fc %Sc %SN\" {} \;"
    f_info_trim=22
    systype="darwin"
else
    # Probably GNU Linux
    f_info="-printf \"%C@ %Cc '%p'\n\""
    f_info_trim=33
    systype="gnu"
fi

# This function is used to set the exit code for the main internal subshell.
go_byebye()
{
    echo \# byebye: $byebye
    exit $1
}

# For a given value and unit (day, hour, or minute), return a display
# string appropriate to the value. If the value is zero, return ''.
newpods_plurals()
{
    local num=$1
    local unit=$2
    local phrase

    if [ $num -gt 1 ]; then
        # The arithmetic evaluation removes a leading zero
        phrase="$(( num )) ${unit}s"
    elif [ $num -eq 1 ]; then
        phrase="1 $unit"
    else
        phrase=""
    fi

    echo $phrase
}

# newpods looks for duration to be entered as nndhh:mm. This routine
# converts seconds into this representation. For convenience in
# display, a caller can also pass in a string that will be prepended
# to the representation.
# The caller can request either a 'short' representation, or a 'long'
# one.
newpods_seconds_to_timerep()
{
    local secs=$1
    local type=$2
    local prefix=${3:-''}

    local back_mins=$(( ( secs / 60 ) % 60 ))
    local back_hours=$(( ( secs / 3600 ) % 24))
    local back_days=$(( secs / 86400 ))
    #echo back: $back back_mins: $back_mins back_hours: $back_hours back_days: $back_days >&2

    if [[ $type == "short" ]]
    then
        local back_repr=$(printf "%3dd%02d:%02d" $back_days $back_hours $back_mins)
    else
        local back_repr="$(newpods_plurals $back_days day) $(newpods_plurals $back_hours hour) $(newpods_plurals $back_mins minute)"
    fi
    #echo back_repr: $back_repr >&2

    echo ${prefix}$back_repr
}

# Get the last time newpods was run. Returns "seconds before now"; if
# newpods was last run an hour ago, this should return "3600" (note
# that the number is positive).
# If there is no last time, return "24*60*60" (=86400 for 24 hours in seconds)
retrieve_last_time()
{
    local last_run_time
    # Extract just the first number from the file
    if [[ -r $last_time_filename ]]
    then
        # Use [^0-9]* instead of .* because * in sed is always greedy
        last_run_time=$(sed -ne 's/[^0-9]*\([0-9][0-9]*\).*/\1/p' < "$last_time_filename")
    else
        last_run_time=$(( $(date '+%s') - 86400 ))
    fi
    local lasttime=$(( $(date '+%s') - last_run_time ))
    DEBUG && echo retrieve_last_time returning $(newpods_seconds_to_timerep $lasttime 'short') >&2
    echo $(newpods_seconds_to_timerep $lasttime 'short')
}

# Set the last time newpods was run. Expects an argument in seconds.
set_last_time()
{
    echo "last time, in seconds, that newpods was run" > $last_time_filename
    echo $1 >> $last_time_filename
}

nag=1
nag()
{
    if [ "$nag" -eq 1 -a "$is_script" -eq 1 ]; then
        cat <<EOF1
    If you source this script instead of running it as a program,
    newpods will add commands to your bash command history, so you can
    just use the up-arrow to get to the commands, instead of
    copy-and-paste. Put the following line in your ~/.bashrc file:
EOF1
    here=$(dirname "$BASH_SOURCE")
    echo "alias newpods='. $(cd "$here"; pwd)/$(basename $BASH_SOURCE)'"
    fi
}

DEBUG()
{
    test $debug -eq 1
}

Usage()
{
    echo "$@"
    cat <<EOF
Usage: newpods [-d] [-v] [-h] [-m] [hours]

    -d    Turns on debugging information
    -v    Returns the version.
    -h    Displays this message.
    -m    Displays a user guide.

    hours How far back in time to go to consider a pod file as
          new. The default value is 24.

    newpods shows you which newly-downloaded pod files to copy from
    your host computer to a portable media player.

EOF
    nag
}

# Extract the man page and send it to stdout.
PrintMan()
{
    sed -ne '/^: ...END_OF_MAN_PAGE./,$p' <"$BASH_SOURCE"
}

# Print the version string to stdout.
Version()
{
    # Maintenance note: don't forget to update date and version number in man page.
    echo Newpods, version 0.8.0
}

# This is the path to a file that newpods uses to remember the last
# time it was run. It's a convenience only, and may be deleted at any
# time without harm.
last_time_filename=${TMPDIR:-/tmp}"/newpods.txt"

args=`getopt dhmvqQ $*`
           # you should not use `getopt abo: "$@"` since that would parse
           # the arguments differently from what the set command below does.

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; go_byebye 1 ; fi

set -- $args
           # You cannot use the set command with a backquoted getopt directly,
           # since the exit code from getopt would be shadowed by those of set,
           # which is zero by definition.

debug=0
while true ; do
    case "$1" in
	-d) debug=1; shift ;;
	-v) Version;  go_byebye 1;;
	-h) Usage; go_byebye 1;;
        -m) PrintMan; go_byebye 3;;
        -q) nag=0; shift;;
	-Q) shift ;;
	--) shift ; break ;;
        *)  Usage "Unrecognized option $1"; go_byebye 2;;
    esac
done

if [[ $is_sourced -eq 1 ]]; then
    DEBUG && echo "running as a sourced script!" >&2
else
    DEBUG && echo "running as a script" >&2
fi

# Extract a list of values from a configuration file. Note that a
# default config file is near the end of this script.
# Inputs:
#     defname     The name of the property to read.
#     script      The name of the configuration file.
#     default     The value to supply if the property is not set in
#                 the config file.
#     badvalue    An illegal value. This is used because some values
#                 in the default configuration must be changed before
#                 use.
# Outputs:
#     arydef      This is a bash array. It must be defined before the
#                 first call to extract_def(). It is an array to allow
#                 the property to have multiple values. See below for
#                 examples of use.
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
    DEBUG && echo arydef is "${arydef[@]}" sizeof arydef is: ${#arydef[@]} badvalue is \"$badvalue\" >&2
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
            echo Configuration file not changed >&2
            echo In the configuration file \"$script\", the value of \"$defname\" has not been changed >&2
            echo from the initial default value. >&2
            echo Please edit the configuration file \"$script\" so that the values match your system >&2
            return 1
        fi
    fi
    return 0
}

# Where is our init file?
# Look in three places, in order:
#   current directory
#   script's directory
#   user's home directory
init_loc=''
for i in . "$(basename "$BASH_SOURCE")" "$HOME"
do
    DEBUG && echo Looking for initialization file "$i/.newpodsrc" >&2
    if [ \( -e "$i/.newpodsrc" \) -a \( -z "$init_loc" \) ]
    then
        init_loc="$i/.newpodsrc"
        DEBUG && echo Found initialization file $init_loc >&2
    fi
done

# Couldn't find a configuration file. Make a default one.
if [[ -z $init_loc ]]
then
    init_loc="${HOME}/.newpodsrc"
    echo "  First run. Installing user configuration file in ${init_loc}"
    echo "  You MUST edit this file before running newpods again."
    sed -ne '/DEFAULT_CONFIGURATION.$/,/^DEFAULT_CONFIGURATION/p' "$BASH_SOURCE" |
       sed -e '/DEFAULT_CONFIGURATION/d' >"$init_loc"
    go_byebye 0
fi

time_arg=${1:-$(retrieve_last_time)}
# Validate the time argument
if echo "$time_arg" | egrep -q "^([0-9]*d)?[0-9]*(:[0-5][0-9])?$"
then
    eval `echo $time_arg | sed -ne 's/\([0-9]*d\)\{0,1\}0*\([0-9]*\):\{0,1\}0*\([0-9]*\)\{0,1\}/day=\"\1\";hr=\"\2\";mn=\"\3\"/p'`
    mn=${mn:-0}
    hr=${hr:-0}
    day=${day:-0d}
    day=${day%d}
    mins=$(( mn + 60 * hr + 1440 * day))
    normalized_seconds=$(( mins * 60 ))
    DEBUG && echo For \"$time_arg\", days result is \"$day\" >&2
    DEBUG && echo For \"$time_arg\", hours result is \"$hr\" >&2
    DEBUG && echo For \"$time_arg\", minutes result is \"$mn\" >&2
else
    echo Unrecognized time specifier \"$time_arg\" >&2
    go_byebye 2
fi

declare -a source
declare -a destinations
declare -a good_extensions
declare -a arydef

# Get the name of the source tree from the configuration file. There
# is no default value, and the value must not be '/path/to/podcasts'
# (because that's the value in the template)
extract_def source "$init_loc" "" "/path/to/podcasts"
test $? -eq 0 || go_byebye 1
source=("${arydef[@]}")

# Get the list of destinations from the configuration file. There is
# no default value, and the value must not be
# '/path/to/portable/player' (because that's the value in the
# template)
extract_def destinations "$init_loc" "" "/path/to/portable/player"
test $? -eq 0 || go_byebye 1
destinations=("${arydef[@]}")

# Get the list of desired file extensions from the configuration
# file. There is no default value, and the extracted value is not
# checked.
extract_def extensions "$init_loc" "" ""
good_extensions=("${arydef[@]}")

# Get the desired transfer command. The default is "cp -v", and the
# extracted value is not checked.
extract_def transfer_command  "$init_loc" "cp -v" ""
transfer_command="${arydef[0]}"

# Look for the first destination that's present. If none is found
# (probably because no portable device has been plugged in), the value
# is set to "/dev/null".
there=/dev/null
for dest in "${destinations[@]}"; do
    DEBUG && echo Checking for destination $dest >&2
    if ls $dest >& /dev/null; then
        DEBUG && echo Found $dest >&2
        there=$dest
        break
    fi
done

if [[ $there = "/dev/null" ]]; then
    DEBUG && echo Did not find a device to copy to! >&2
else
    DEBUG && echo Destination directory is: $there >&2
fi

# Build up a 'find' expression to look only for files with extensions
# we're interested in.

DEBUG && echo Looking for file extensions: ${good_extensions[*]} >&2
re='\( -iname '
# Put a special token where we're going to want '-o'. Note that this
# technique will leave an extra BGAFFLE token at the end.
for ext in "${good_extensions[@]}"; do
    re="$re"'\*.'"$ext"BGAFFLE
done
# trim off last token
re="${re%BGAFFLE}"
# Change the other tokens into ' -o '
re="${re//BGAFFLE/ -o -iname }"' \)'
DEBUG && echo extension search is \"$re\" >&2

now=$(date '+%s')
cutoff=$(( now - mins * 60 ))

# For some reason, the ${source[0]} doesn't get globbed in the 'find' command. Force it here.
source_dir=$( (eval cd "${source[0]}"; pwd) )
IFS=$'\n'
old_file_list=()
new_file_list=()
latest_file_list=()
file_count=1
for i in $(eval find "$source_dir" -type f $re $f_info | sort -n)
do
    then=$(echo $i | cut -d . -f 1)
    file_info=$(echo $i | sed -e 's/^[^ ]* //')
    back_repr=$(newpods_seconds_to_timerep $(( now - then )) 'short')
    # DEBUG && echo back: $back back_mins: $back_mins back_hours: $back_hours back_repr: $back_repr >&2
    if [[ $then -ge $cutoff ]]
    then
        new_file_list+=("$back_repr $file_info")
        # Get a list with just file names and surround the names with single quotes
        # to allow for spaces and other strange characters in the file names
        latest_file_list+=($(echo "$file_info" | cut -c ${f_info_trim}-))
        # It was hard to get the quoting to work correctly on Linux
        # and Mac OS X; bash seems to work differently in this respect.
        quoted_latest_file_list+=("'"$(echo "$file_info" | cut -c ${f_info_trim}-)"'")
        quoted_quoted_latest_file_list+=("\'"$(echo "$file_info" | cut -c ${f_info_trim}-)"\'")
    else
        old_file_list+=("$back_repr $file_info")
    fi
    DEBUG && file_count=$(( file_count + 1 ))
done

DEBUG && echo Processed $file_count files >&2
echo "     age         date                       file name"
echo "    d:hh:mm   downloaded"
for i in ${old_file_list[@]}
do
    echo " "$i
done | tail -10

for i in ${new_file_list[@]}
do
    echo "*"$i
done

echo
echo
echo
echo $(newpods_seconds_to_timerep $normalized_seconds 'long' 'From the last ')
echo
echo

echo Use the following commands:

# Don't issue a pushd command unless there is somewhere to go
[[ $there != /dev/null ]] && echo pushd "'"$there"'"

if [[ ${#latest_file_list[@]} -eq 0 ]]; then
    echo "Nothing to copy"
elif [ "$systype" = "gnu" ]; then
    echo $transfer_command "${latest_file_list[@]}" "'"$there"'"
else
    echo $transfer_command "${quoted_latest_file_list[@]}" "'"$there"'"
fi

if [[ $is_sourced -eq 1 ]]; then
    #echo
    #echo These commands are in your bash history list. Use up-arrow to get to them.
    #echo
    # We're running as a sourced script! Yay!
    # Push the handy commands on the history stack. Actually, tell the
    # code at the bottom of the script to do this.
    echo \# CUT THIS LINE AND BELOW
    [[ ${#latest_file_list[@]} -ne 0 ]] && echo history -s $transfer_command "${quoted_quoted_latest_file_list[@]}" "\'"$there"\'"
    [[ $there != /dev/null ]] && echo history -s pushd "\'"$there"\'"
    this_cmd=`history 1`
    # Remove the leading command number and spaces
    this_cmd=`echo $this_cmd | sed -e 's/ *[0-9][0-9]* *//'`
    echo history -s $this_cmd
fi

set_last_time $now

# Otherwise, we're running as a shell script. Can't alter the history stack...
nag
) >newpods_tmp1.$$$$

newpods_status=$?

# The exit status is used to indicate what to do with the output
# captured in newpods_tmp1.$$$$.
# A status of 3 means we should print out a man page
# A status of 1 means we should print out something that is already
# formatted.
# A status of 0 means we should carry out the standard function: to
# report on new downloads.

if [[ $newpods_status -eq 3 ]]
then
    # We should print out a man page
    if uname -a | grep -i linux >& /dev/null
    then
        tail -n +2 newpods_tmp1.$$$$ | head --lines=-2 | man -l -
    else
        tail -n +2 newpods_tmp1.$$$$ | tail -r | tail -n +3 | tail -r | groff -tman -T ascii | more
    fi
elif [[ $newpods_status -eq 1 ]]
then
    # We have something else to print
    cat newpods_tmp1.$$$$ | egrep -v 'byebye'
elif [[ $newpods_status -eq 0 ]]
then
    # We're OK to continue
    cat newpods_tmp1.$$$$ | sed -ne '1,/CUT THIS LINE AND BELOW/p' | egrep -v 'CUT THIS LINE AND BELOW'
    cat newpods_tmp1.$$$$ | sed -ne '/CUT THIS LINE AND BELOW/,$p' | egrep '^history ' >newpods_tmp2.$$$$

    # If newpods_tmp2.$$$$ exists and is not empty, then we have some history lines to insert.
    # Otherwise, we are running as a script
    test -s newpods_tmp2.$$$$ && source newpods_tmp2.$$$$
fi

unset newpods_status
rm -f newpods_tmp1.$$$$ newpods_tmp2.$$$$

: <<'DEFAULT_CONFIGURATION'
# Where are the pod files kept?
#
# If they are in a single directory (like bashpodder), put that
# here. If they are in multiple directories in a tree of directories
# (like Juice or podget), put the top directory of the tree here.
# Currently, there should be only one source directory
[source]
#   /this/path/is/commented/out
   /path/to/podcasts

# Where do the pod files go?
#
# When a portable media player is plugged in, it typically shows up as
# a directory somewhere in the file system. For instance, when I plug
# in my Sansa Clip, it shows up as '/media/rem/sansa'. I want the pod
# files to go in the MUSIC directory on the Sansa, so the destination
# would be '/media/rem/sansa/MUSIC'. 'destinations' is a list of
# directories to be used as possible destinations. The first one in
# the list that is found is used as the destination for pod
# files. These directory names may contain spaces.
[destinations]
  #/media/rem/iaudio/music/pods
  #	/media/rem/cowon/music/pods
  #/media/rem/sansa/MUSIC STUFF
  #/media/rem/sansa/MUSIC
  /path/to/portable/player

# What kinds of pod files should we transfer?
#
# The following is a list of common file extensions for music
# files. This script will look for and transfer files with the
# indicated extensions. It will ignore extensions that are preceded by
# a '#'.
[extensions]
mp3
ogg
#flac
#fla
#wav
#aac
#mp4
#m4a

# How should we transfer the files?
#
# By default, the script will just copy pod files from the source to
# the destination. You may want to do something fancy with the files;
# perhaps you would want to change the ID3 tags. If so, put the name
# of your script here.
[transfer_command]
# default command is:  cp -v
DEFAULT_CONFIGURATION

: <<'END_OF_MAN_PAGE'
.TH "NEWPODS" "1" "11/24/2009" "newpods 0\&.8\&.0" "Newpods Manual"
.\" disable hyphenation
.nh
.\" disable justification (adjust text to left margin only)
.ad l
.SH "NAME"
newpods \- Find recently downloaded podcasts and suggest useful commands
.SH "SYNOPSIS"
\fInewpods\fR  [\-d] [\-h] [\-m] [\-v] [\-q] [\-Q] [timespec]
.SH "DESCRIPTION"
For the impatient, see the QUICK START section below.

This script is used to find recently downloaded podcasts, and can
insert the proper commands into the \fBbash\fP shell's command history
list to copy them to a portable player into the
bash history list. The location of the podcast directory tree and the
location of the portable player are set in the configuration file
\fI.newpodsrc\fP.

By default, \fBnewpods\fP will look for podcasts that have been
downloaded since the last time the program was run, or, if
\fBnewpods\fP has not been run before, in the last 24 hours. This
search time can be set by giving \fBnewpods\fP a time specification. A
time specification indicates a time before the current time. Files
newer than this are considered 'new', and \fBnewpods\fP will create a
command to copy them to the destination. The format of a time
specifiction is perhaps most easily shown by example.
.sp
.TP
12
Indicates 12 hours. A plain integer is interpreted as a number of
hours.

.TP
:30
Indicates 30 minutes. This may be used with hours, so 7:04 represents
7 hours and 4 minutes.

.TP
1d
A number followed by a 'd' indicates a number of days. A day is the
same as 24 hours. This may be combined with hours and minutes, so 1d3
represents 1 day 3 hours, and 1d1:01 represents 1 day 1 hour and 1
minute.

.RS 0
There is no restriction on the value of the days or hours parameter,
but minutes must be between 0 and 59.
.RE

\fBnewpods\fP
assumes that podcasts are downloaded into either a single directory
or a tree of subdirectories underneath a single directory, and that
podcasts should be copied into a single directory. This
means \fBnewpods\fP
will only work with players that support UMS (USB Mass Storage). UMS
players look just like USB drives on a computer \- they will show up
as a directory somewhere in the file system. On a Mac, they will
appear in the /Volumes directory. For example, an iRiver might
show up as "/Volumes/iRiver U10". \fBnewpods\fP
handles different players by keeping a list of the directories in
which each player appears, and then stepping through this list. The
first directory \fBnewpods\fP
finds that currently exists on the machine is considered to be the
target directory for the run.
.sp
.sp
.RS 4
.nf
newpods
\&. \<path\-to\-newpods\-file\>/newpods
.fi
.sp
.RE
In the first form, it finds the newest podcasts, and suggests a
command to copy them to a portable device. In the second form, the
script can put these commands into the bash history list, where they
can be accessed with an up-arrow key. To use the second form, it
would be most convenient to set up an alias:
.sp
.RS 4
.nf
alias newpods='. $HOME/bin/newpods'
.fi
.RE
.sp
assuming you put \fBnewpods\fP in the bin directory in your home
directory. Otherwise, replace $HOME/bin with whatever directory you put \fBnewpods\fP in.
.sp
\fBNewpods\fP should correctly handle file and directory names that
contain spaces.
.SH "OPTIONS"
.PP
\-v
.RS 4
Print version information and exit.
.RE
.PP
\-h
.RS 4
Print a short help summary and exit.
.RE
.PP
\-m
.RS 4
Print a detailed user guide and exit.
.RE
.PP
\-d
.RS 4
Prints some extra information while the script runs.
.RE
.PP
\-Q
.RS 4
Disables the display of the copyright and license information.
.RE
.PP
\-q
.RS 4
Disables the alias\-nag when \fBnewpods\fP is run as a script.
.RE
.SH "QUICK START"
Run \fBnewpods\fP once. This will create a default configuration file
named \fI.newpodsrc\fP in your home directory.

Edit the information in this file to match your system.
.RS 4
You will need at least to change 'source' (to point to
wherever your new podcasts are) and 'destinations' (to where you want
\fBnewpods\fP to copy the podcasts to. If you have more than one
portable device, make one entry for each device (see examples in
\fI.newpodsrc\fP for more information).
.RE

Make an alias:
.RS 4
alias newpods='. path-to-newpods'

where \fBpath-to-newpods\fP is wherever the \fBnewpods\fP script is
located.

If you do it this way (invoking it with a '.'), \fBnewpods\fP will be
able to put the appropriate commands in the bash history, where you
can access them with an up-arrow. \fBnewpods\fP does not do any
copying itself. It puts a 'pushd \fBpath-to-destination\fP' on the
history list, so you can go delete any files you've already listened
to, and then a 'cp -v <all the new podcasts> <path-to-destination>',
to copy them there, once you're satisfied with the current contents
of your music player.
.RE

Run it.
.RS 4
newpods 24

will find all the podcasts that have been downloaded in the last 24
hours.

newpods 2d

will find all the podcasts that have been downloaded in the last 48
hours.

newpods

will find all the podcasts that have been downloaded since the last
time newpods was run.

newpods -d

will find all the podcasts that have been downloaded since the last
time newpods was run and spit out all sorts of information about what
it's doing.

.RE
.SH "FILES"
There is one file associated with \fBnewpods\fP; the configuration
file \fI.newpodsrc\fP. \fBnewpods\fP will search for this file in
three locations, and will use the first one it finds. The locations
are: 1) The user's current directory, 2) the directory that contains
\fBnewpods\fP, and 3) the user's home directory. For further details,
see the comments in the file itself.

If this file does not exist, \fBnewpods\fP will create a template
version in the user's $HOME directory. This template version must be
edited to put in the correct values for 'source' and 'destinations'
before \fBnewpods\fP is run again.
.SH "DIAGNOSTICS"
The following diagnostics may be issued on stderr:
.TP
No configuration value found for "source"
There was no entry in \fI.newpodsrc\fP for the source tree. There
needs to be exactly one source tree specified.
.TP
No configuration value found for "destinations"
There was no entry in \fI.newpodsrc\fP for the destination directory. There
needs to be at least one directory specified.
.TP
Configuration file not changed
The rest of the message is: In the configuration file "<name of
configuration file>", the value of "<source or destinations" has not
been changed from the initial default value.  Please edit the
configuration file "<name of configuration file>" so that the values
match your system.

When \fBnewpods\fP creates a configuration file, it puts in values for
"source" and "destinations" that it knows can never be correct. These
values \fImust\fP be changed appropriately for your system. There are
some suggestions and examples in the configuration file.
.TP
Unrecognized time specifier "<some wrong time spec>"
\fBnewpods\fP is fairly strict about what it will accept as a time
value. See above for examples.
.TP
Did not find a device to copy to!
\fBnewpods\fP could not find any of the directories listed in the
"destinations" section of the configuration file. This could happen if
the destinations refer to one or more portable music players, none of
which are currently attached to the computer.
.SH "BUGS"
Please report any bugs to the tracker at the Sourceforge project page:
http://sourceforge.net/projects/newpods/
.SH "AUTHOR"
Written by Bob Forgey <\fIrforgey at grumpydogconsulting dot com\fR>
.sp
.RE
END_OF_MAN_PAGE

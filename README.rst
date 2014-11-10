=========
 newpods
=========

---------------------------------------------------
find recently downloaded podcasts and transfer them
---------------------------------------------------

:Author: rforgey@grumpydogconsulting.com
:Date:   2014-11-24
:Copyright: Bob Forgey (C) 2009-2014
:License: GPL v3
:Version: 1.0.0
:Manual section: 1
:Manual group: media processing

.. TODO: authors and author with name <email>

SYNOPSIS
========

newpods [options]

DESCRIPTION
===========

Newpods is a script that can find recently downloaded podcasts. It
creates the proper commands to copy them to a portable player and
inserts the commands into the user's bash history list, or just runs
the commands automatically.

For the impatient, see the QUICK START section below.

This script is used to find recently downloaded podcasts, and can
insert the proper commands into the bash shell's command history list
to copy them to a portable player into the bash history list. The
location of the podcast directory tree and the location of the portable
player are set in the configuration file .newpodsrc.

By default, newpods will look for podcasts that have been downloaded
since the last time the program was run, or, if newpods has not been
run before, in the last 24 hours. This search time can be set by giving
newpods a time specification. A time specification indicates a time
before the current time. Files newer than this are considered 'new',
and newpods will create a command to copy them to the destination. The
format of a time specifiction is perhaps most easily shown by example::

  12     Indicates 12 hours. A plain integer is interpreted as a number
         of hours.


  :30    Indicates 30 minutes. This may be used with hours, so 7:04
         represents 7 hours and 4 minutes.


  1d     A number followed by a 'd' indicates a number of days. A day is
         the same as 24 hours. This may be combined with hours and
         minutes, so 1d3 represents 1 day 3 hours, and 1d1:01 represents
         1 day 1 hour and 1 minute.

There is no restriction on the value of the days or hours parameter,
but minutes must be between 0 and 59.

newpods assumes that podcasts are downloaded into either a single
directory or a tree of subdirectories underneath a single directory,
and that podcasts should be copied into a single directory. This means
newpods will only work with devices that show up somewhere in the file
system. For devices that don't show up like this, you can send the
output to a local directory and copy the files to your device from
there. newpods handles different players by keeping a list of the
directories in which each player appears, and then stepping through
this list. The first directory newpods finds that currently exists on
the machine is considered to be the target directory for the run.

    newpods
    . <path-to-newpods-file>/newpods

In the first form, it finds the newest podcasts, and suggests a command
to copy them to a portable device. In the second form, the script can
put these commands into the bash history list, where they can be
accessed with an up-arrow key. To use the second form, it would be most
convenient to set up an alias::

    alias newpods='. $HOME/bin/newpods'

assuming you put newpods in the bin directory in your home directory.
Otherwise, replace $HOME/bin with whatever directory you put newpods
in.

Newpods also has an option to automatically transfer the files it's
found, once you're comfortable with the way it works. Give a ``-x`` flag
to newpods, and it will run the 'after_command' (defined in the
configuration file) after it has found the latest files. If you don't
define an after_command, it will use the value of
'transfer_command'. If you use the "-x" flag, you might as well run it
as a regular script, rather than sourcing it, since you don't need to
add anything to the bash command history.

Newpods should correctly handle file and directory names that contain
spaces. It should also run correctly on Linux, Mac, and BSD systems.

OPTIONS
=======

-v    Print version information and exit.

-h    Print a short help summary and exit.

-m    Print a detailed user guide and exit.

-d    Prints some extra information while the script runs.

-Q    Disables the display of the copyright and license information.

-q    Disables the alias-nag when newpods is run as a script.

-x    Run the 'after_command' automatically once the recent files have
      been located.

QUICK START
===========

* Run newpods once.

This will create a default configuration file named
``.newpodsrc`` in your home directory.

* Edit the information in this file to match your system.

You will need at least to change 'source' (to point to wherever
your new podcasts are) and 'destinations' (to where you want
newpods to copy the podcasts to. If you have more than one portable
device, make one entry for each device (see examples in ``.newpodsrc``
for more information).

* Make an alias::

    alias newpods='. path-to-newpods'

where path-to-newpods is wherever the newpods script is located.

If you do it this way (invoking it with a '.'), newpods will be
able to put the appropriate commands in the bash history, where you
can access them with an up-arrow. newpods does not do any copying
itself. It puts a 'pushd path-to-destination' on the history list,
so you can go delete any files you've already listened to, and then
a 'cp -v <all the new podcasts> <path-to-destination>', to copy
them there, once you're satisfied with the current contents of your
music player.

* Run it.

EXAMPLES
========

newpods 24
   will find all the podcasts that have been downloaded in the last 24
   hours.

newpods 2d
   will find all the podcasts that have been downloaded in the last 48
   hours.

newpods
   will find all the podcasts that have been downloaded since the last
   time newpods was run.

newpods -x
   will find all the podcasts that have been downloaded since the last
   time newpods was run and copy them to the destination directory.

newpods -d
   will find all the podcasts that have been downloaded since the last
   time newpods was run and spit out all sorts of information about
   what it's doing.


FILES
=====

There is one file associated with newpods; the configuration file
``.newpodsrc``. newpods will search for this file in three locations,
and will use the first one it finds. The locations are: 1) The user's
current directory, 2) the directory that contains newpods, and 3) the
user's home directory. For further details, see the comments in the
file itself.

If this file does not exist, newpods will create a template version in
the user's $HOME directory. This template version must be edited to put
in the correct values for 'source' and 'destinations' before newpods is
run again.

DIAGNOSTICS
===========

The following diagnostics may be issued on stderr:

No configuration value found for "source"
       There was no entry in .newpodsrc for the source tree. There
       needs to be exactly one source tree specified.

No configuration value found for "destinations"
       There was no entry in .newpodsrc for the destination directory.
       There needs to be at least one directory specified.

Configuration file not changed
       The rest of the message is: In the configuration file "<name of
       configuration file>", the value of "<source or destinations" has
       not been changed from the initial default value.  Please edit
       the configuration file "<name of configuration file>" so that
       the values match your system.

       When newpods creates a configuration file, it puts in values for
       "source" and "destinations" that it knows can never be correct.
       These values must be changed appropriately for your system.
       There are some suggestions and examples in the configuration
       file.

Unrecognized time specifier "<some wrong time spec>"
       newpods is fairly strict about what it will accept as a time
       value. See above for examples.

Did not find a device to copy to!
       newpods could not find any of the directories listed in the
       "destinations" section of the configuration file. This could
       happen if the destinations refer to one or more portable music
       players, none of which are currently attached to the computer.


BUGS
====

Please report any bugs to the tracker at the Github project page:
https://github.com/sesamemucho/newpods/issues


# HINTS - A place for generic tips and tricks

 You can add tips and tricks here, just load this up in the editpr and add what you want

## EXPORT TOKENIZED BASIC PROGRAMS TO TEXT
 Ancient arcane knowledge of kelli:  

 To export tokenized basic programs back out as text files, do the following:

 OPEN 2,8,2,"PROGRAM.BAS,S,W":CMD2:LIST
 PRINT#2:CLOSE2

 Replace program.bas as the desired filename. Replace "2" with desired
 File number if 2 is already in use.

 Use "@:PROGRAM.BAS" to overwrite existing file if it exists.

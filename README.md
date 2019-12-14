# Computer Architecture Project 3

This repository contains the code for a group project that I worked on in my computer architecture class.

The project goal was to build a simple instruction set architecture (ISA) simulator using a language of the group's choice. My group chose scala, and I decided to also create a julia version. We worked on an example python version in class.

The full project description (copied from the [course webpage](https://share.houghton.edu/hc/personal/RyanYates/2019-Fall/CSCI226/projects/3.html)) can be found in `projectDescription.md`. If the above link is broken or unavailable, the aforementioned markdown file should be enough to get an understanding of the project.

# R-ASCII
The reduced ASCII instruction set architecture simulator.

The files `ram.scala`, `ram.py`, and `ram.jl` can be run with the following:
```
$ scala -nc ram.scala <ram-file (e.g, bin-sort.ram)> <mode (i.e, 1, 2, 3, or 4)>
$ python3 ram.py <ram-file (e.g, bin-sort.ram)> <mode (one of 1, 2, 3, or 4)>
$ julia ram.jl <path-to-ram-file> <mode (one of 1, 2, 3, or 4)>
```

For example, running the bin-sort.ram file on mode 2 using julia would be:
```
$ julia ram.jl ram_files/bin-sort.ram 2
```

The valid modes are 1, 2, 3, or 4. They are described below (copied from `projectDescription.md`):

1. Output a trace of execution that includes on each line the instruction executed, the new values of any registers changed by that instruction, and the address and value of any changed memory locations.
2. Execute without tracing (faster) and output the values in each data section at the end of execution. Use the second value in each the data section header as the number of memory locations to display at the end.
3. Execute without tracing and perform OS I/O operations.
4. Analyse the program by outputting all the read-after-write hazards in the program. For each one, output the addresses and pair of instructions.

## Notes
The python version is incomplete, as my group and I never worked on it.

The julia and scala version are not as robust as I'd like them to be. In particular, I'd love to go back to the julia file and make the logic within it more "julian".
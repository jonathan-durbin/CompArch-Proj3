# Problem
Hardware design often needs a suite of specialized tools to analyse and debug the design. For this project we will make an emulator for a toy RISC-like ISA that has some simplifications to make things a bit easier. With this emulator we will explore some interesting analysis and a few operating systems concepts.

# R-ASCII ISA
To simplify our ISA will use an encoding with four bytes for most instructions where each byte is a printable character in ASCII encoding. The first byte will serve as opcode (including ALU functionality selection) and the subsequent bytes will either be registers or immediate values given as hexadecimal digits. The opcode will dictate if a character is a register or hex digit by position.

The following tables describes all the opcodes and how the three characters that follow are used, *S* for source register, *D* for destination register, *R* for read memory at register address, *W* for write memory at register address, *M* for multiple use register, *H* for hex digit, and _ for unused.

| Op | Description |
| -- | ------------|
| **L** *R*  *D* _ | Load from memory at the address in register *R* and put the value in register  *D*. |
| **S**  *S*  *W* _ | Store the value from register  *S* to memory at the address in register  *W*. |
| | |
| **+**  *S1*  *S2*  *D* |  Add the values from registers  *S1*  *S2* and  *S2* and put the result in register  *D*. |
| **-**  *S1*  *S2*  *D* | Subtract the value of registers  *S2* from  *S1* and put the result in register  *D*. |
| **\***  *S1*  *S2*  *D* | Multiply the values from registers  *S1* and  *S2* and put the result in register  *D*. |
| **/**  *S1*  *S2*  *D* | Divide the value of registers  *S2* from  *S1* and put the result in register  *D*. |
| **%**  *S1*  *S2*  *D* | Divide the value of registers  *S2* from  *S1* and put the remainder in register  *D*. |
| | |
| **B**  *S*  *Hh*  *Hl* | Branch. Add  *Hh* *Hl* times 2 to the PC if the value in register  *S* is not zero. |
| **b**  *S*  *Hh*  *Hl* | Branch. Subtract  *Hh*  *Hl* times 2 from the PC if the value in register  *S* is not zero. |
| **E**  *S*  *Hh*  *Hl* | Branch. Add  *Hh*  *Hl* times 2 to the PC if the value in register  *S* is equal zero. |
| **e**  *S*  *Hh*  *Hl* | Branch. Subtract  *Hh*  *Hl* times 2 from the PC if the value in register  *S* is equal zero. |
| **<**  *S*  *Hh*  *Hl* | Branch. Add  *Hh*  *Hl* times 2 to the PC if the value in register  *S* is less than zero. |
| **l**  *S*  *Hh*  *Hl* | Branch. Subtract  *Hh*  *Hl* times 2 from the PC if the value in register  *S* is less than zero. |
| **>**  *S*  *Hh*  *Hl* | Branch. Add  *Hh*  *Hl* times 2 to the PC if the value in register  *S* is greater than zero. |
| **g**  *S*  *Hh*  *Hl* | Branch. Subtract  *Hh*  *Hl* times 2 from the PC if the value in register  *S* is greater than zero. |
| | |
| **R**  *S* _ _ | Return. Set PC to the value in register  *S*. |
| **H** _ _ _  | Halt. Stop executing. |

There are two additional instructions that take up 8 bytes each:

| Op | Description |
| -- | ----------- |
| **J**  *D* _ _ *H3* *H2* *H1* *H0* | Jump. Set register  *D* to the value of PC plus 4. Set PC to the value given by the hex string *H3* *H2* *H1* *H0*. |
| **I**  *D* _ _ *H3* *H2* *H1* *H0* | Load Immediate. Set register  *D* to the value given by the hex string *H3* *H2* *H1* *H0* |

The machine itself is 16-bit, each register holds a 16-bit value. Each instruction takes up either two or four memory locations. The registers named by the ASCII digit characters `'0'` through `'9'` hold the value of that digit and cannot be overwritten. All other registers initially are zero. Values for conditions should be interpreted as two's complement 16-bit integers. The program counter (PC) is register `'P'` (initially zero, so all programs start executing with the instruction at memory location zero). Unless otherwise noted, the PC will increase by two after each instruction.

# Operating System Support
R-ASCII ISA supports operating system interaction with a "syscall" instruction:

| Op | Description |
| -- | ----------- |
| **!** *M*  *Hh*  *Hl* | Syscall. Invoke operating system functionality number  *Hh*  *Hl* (in hexadecimal) reading from and/or writing to the register given as the second character. |

We will only have very simple I/O operations:

| Syscall | Description |
| ------- | ----------- |
| !a01 | Print string. OS will output a NULL terminated UTF-16 string from memory at the address given by register a. (Note: none of the examples use values outside of the printable ASCII so you can treat the values as ASCII bytes if that is easier). |
| !a02 | Read word. OS will read input from the user, parse it as a 16-bit number, and write that value to register a. |

# R-ASCII Executable File Format
Executable programs are written in an easy to parse file format. The file is divided up into code and data sections signaled by a header line. For example:

```
code: 0x1000
```

indicates the start of a code section with instructions to be placed in memory location 1000 (hexadecimal). Inside code sections each line will be four bytes of instruction. Eight byte instructions will span two lines. The first four non-whitespace ASCII bytes of each of these lines will fill two memory locations.

Data sections have a similar header:

```
data: 0x2000 10
```

Like with code sections the first number in the header is the memory location for subsequent data values. The next numbers on the header line specify how to visualize the data and do not affect execution and may be omitted. In this example, a single number indicates that this data section should be visualized with ten memory entries. Values in data sections are given by whitespace separated decimal (no prefix) or hexadecimal ('0x' prefix) numbers. These can span several lines. Data sections can also be empty.
The '#' character at the beginning of a line is a comment and the line can be ignored. Comments can also be put at the end of lines (all characters after and including '#' can be ignored). The beginning of the file is assumed to be in the code section at memory location zero. That is, there is an implicit code header before the first line of the file:

```
code: 0x0
```

# Example
For example, the following program will write to the output memory (address starting at `0x2000`) the values from the input (`0x1000`) with the ones at the beginning and zeros at the end.


```
Ia
1000
Ib
2000
Lan
+a1a # loop:
Lax
Ex03
Sxb
+b1b
-n1n
bn06 # <- loop
H

data: 0x1000 9  # input
8 0 1 1 0 1 1 0 0

data: 0x2000 8  # output
```

# Implementation
Your implementation should be able to take a R-ASCII executable file and execute it in each of the following modes:

1. Output a trace of execution that includes on each line the instruction executed, the new values of any registers changed by that instruction, and the address and value of any changed memory locations.
2. Execute without tracing (faster) and output the values in each data section at the end of execution. Use the second value in each the data section header as the number of memory locations to display at the end.
3. Execute without tracing and perform OS I/O operations.
4. Analyse the program by outputting all the read-after-write hazards in the program. For each one, output the addresses and pair of instructions.

Choose two statistics to collect as a program is running and output these stats at the end.

You will need to model memory and registers in your emulator. Since this is a 16-bit architecture, you can easily model all of memory as a 2^{16} entry array of 16-bit values. In most cases the memory use will be sparse, so a good key–value (dictionary) data structure is a good alternative.

Loading a program can be done in one pass of the executable file read line by line. First check if the line is a code or data header. If it is, set the current memory address and mode appropriately. If it is not, load an instruction into the next two memory locations if the current section is code, otherwise load as many values as there are numbers on the line to starting at the current memory location. Keep track of the data locations and sizes for output later.

Executing instructions can be done in a simple loop that looks at what the current instruction is, performs its work, outputs the updated registers and memory if tracing, collecting and repeat.

After halting, final output can be produced if appropriate by looking at registers and memory.

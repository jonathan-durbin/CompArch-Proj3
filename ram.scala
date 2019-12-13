import scala.io.Source
//TODO or not TODO that is the question
val filename   = args(0)
val mode       = args(1)
var codeMode   = true
var cur        = 0
val mask       = 65535
var mem        = collection.mutable.Map[Int, Int]()
var mem_trunc  = collection.mutable.Map[Int, Int]()
var regs       = collection.mutable.Map[Char, Int]()
var new_regs   = List[Char]()
var new_mem    = List[(Int,Int)]()
var hazard     = List('0', '0', 0) // (reg1, reg2, mem_loc)


def writeM(a: Int, v: Int) = {
    // write the value v to address a in memory, mod mask
    mem(a) = v & mask
    if (mode == "1") new_mem = (a, mem(a))::new_mem
}

def readM(a: Int) = {
    if (!mem.contains(a)) 0
    else mem(a)
}

def writeR(a: Char, v: Int) = {
    // only write to memory if the address is not in [0, 9]
    if (!('0' <= a && a <= '9')) regs(a) = v
    if (mode == "1") new_regs = a::new_regs
}

def readR(a: Char):Int = {
    if('0' <= a && a <= '9'){
        readValue(a.toString)
    } else if (regs.contains(a)) {
        regs(a)
    } else 0
}

def readI(a: Int) = {
    val x = readM(a)
    val y = readM(a+1)
    Array(
        x & 0xff, (x >> 8) & 0xff,
        y & 0xff, (y >> 8) & 0xff
    ).map(_.toChar).mkString("")
}

def readValue(a: String) = {
    if (a.startsWith("0x"))
        Integer.parseInt(a.stripPrefix("0x"), 16)
    else
        Integer.parseInt(a, 10)
}


var stop = false
// for (line <- Source.fromFile(filename).getLines) {
val lines = Source.fromFile(filename).getLines
var writeSeen = false
while (lines.hasNext && !stop) {
    val line = lines.next()
    if (line.startsWith("code: ")) {
        val address = line.stripPrefix("code: ").split(" ")(0)
        cur = readValue(address)
        codeMode = true
    } else if (line.startsWith("data: ")) {
        val n = line.stripPrefix("data: ").split(" ")
        cur = readValue(n(0))  // memory address
        val t = if (n.length == 2) readValue(n(1)) else 0  // store the truncate value in a mapping, if it exists
        mem_trunc(cur) = t
        codeMode = false
    } else {
        if (codeMode) {
            val code = line.split("#")(0).trim().padTo(4,' ')
            if (code != "    ") {
                writeM(cur,   code(0).toInt % 256
                            +(code(1).toInt % 256)*256)
                writeM(cur+1, code(2).toInt % 256
                            +(code(3).toInt % 256)*256)
                if (mode == "4") {
                    if (!writeSeen) code(0) match {
                        case 'B' if (code(1) != 0) => { hazard = List('P', '0', cur); writeSeen = true }
                        case 'b' if (code(1) != 0) => { hazard = List('P', '0', cur); writeSeen = true }
                        case 'E' if (code(1) == 0) => { hazard = List('P', '0', cur); writeSeen = true }
                        case 'e' if (code(1) == 0) => { hazard = List('P', '0', cur); writeSeen = true }
                        case '<' if (code(1) < 0)  => { hazard = List('P', '0', cur); writeSeen = true }
                        case 'l' if (code(1) < 0)  => { hazard = List('P', '0', cur); writeSeen = true }
                        case '>' if (code(1) > 0)  => { hazard = List('P', '0', cur); writeSeen = true }
                        case 'g' if (code(1) > 0)  => { hazard = List('P', '0', cur); writeSeen = true }
                        case 'L' => { hazard = List(code(2), '0', cur); writeSeen = true }
                        case '+' => { hazard = List(code(3), '0', cur); writeSeen = true }
                        case '-' => { hazard = List(code(3), '0', cur); writeSeen = true }
                        case '*' => { hazard = List(code(3), '0', cur); writeSeen = true }
                        case '/' => { hazard = List(code(3), '0', cur); writeSeen = true }
                        case '%' => { hazard = List(code(3), '0', cur); writeSeen = true }
                        case 'J' => { hazard = List(code(1), 'P', cur); writeSeen = true }
                        case 'I' => { hazard = List(code(1), 'P', cur); writeSeen = true }
                        case '!' => { hazard = List(code(1), '0', cur); writeSeen = true }
                        case 'R' => { hazard = List('P', '0', cur); writeSeen = true }
                        case  _  => // do nothing
                    } else {
                        val s = f"Read-write hazard between addresses ${hazard(2)} and ${cur}, instructions ${readI(hazard(2))} and ${code}."
                        code(0) match {
                            case '+' => if (hazard.contains(code(1)) || hazard.contains(code(2)) || hazard.contains('P')) { println(s); writeSeen = false }
                            case '-' => if (hazard.contains(code(1)) || hazard.contains(code(2)) || hazard.contains('P')) { println(s); writeSeen = false }
                            case '*' => if (hazard.contains(code(1)) || hazard.contains(code(2)) || hazard.contains('P')) { println(s); writeSeen = false }
                            case '/' => if (hazard.contains(code(1)) || hazard.contains(code(2)) || hazard.contains('P')) { println(s); writeSeen = false }
                            case '%' => if (hazard.contains(code(1)) || hazard.contains(code(2)) || hazard.contains('P')) { println(s); writeSeen = false }
                            case 'L' => if (hazard.contains(code(1)) || hazard.contains('P')) { println(s); writeSeen = false }
                            case 'S' => if (hazard.contains(code(2)) || hazard.contains('P')) { println(s); writeSeen = false }
                            case '!' => if (hazard.contains(code(1)) || hazard.contains('P')) { println(s); writeSeen = false }
                            case 'R' => if (hazard.contains(code(1))) { println(s); writeSeen = false }
                            case 'B' => if (hazard.contains('P')) { println(s); writeSeen = false }
                            case 'b' => if (hazard.contains('P')) { println(s); writeSeen = false }
                            case 'E' => if (hazard.contains('P')) { println(s); writeSeen = false }
                            case 'e' => if (hazard.contains('P')) { println(s); writeSeen = false }
                            case '<' => if (hazard.contains('P')) { println(s); writeSeen = false }
                            case 'l' => if (hazard.contains('P')) { println(s); writeSeen = false }
                            case '>' => if (hazard.contains('P')) { println(s); writeSeen = false }
                            case 'g' => if (hazard.contains('P')) { println(s); writeSeen = false }
                            case 'J' => if (hazard.contains('P')) { println(s); writeSeen = false }
                            case 'I' => if (hazard.contains('P')) { println(s); writeSeen = false }
                            case _   => writeSeen = false
                        }
                    }
                }
                cur += 2
            }
        } else {
            val data = line.split("#")(0).trim()
                        .split(" ").filter(_ != "")
                        .map(readValue)
            for (d <- data) {
                writeM(cur, d)
                cur += 1
            }
        }
    }
}


writeR('P', 0)
var inst = ""
var halt = false
do {
    inst = readI(readR('P'))
    inst(0) match{
        // Load and Store
        case 'L' => val r = inst(1)
                    val d = inst(2)
                    val a = readR(r)
                    val v = readM(a)
                    writeR(d, v)
                    writeR('P', readR('P') + 2)
        case 'S' => val s = inst(1)
                    val w = inst(2)
                    val a = readR(w)
                    val v = readR(s)
                    writeM(a, v)
                    writeR('P', readR('P') + 2)
        // Mathematical Operands
        case '+' => val s1 = inst(1)
                    val s2 = inst(2)
                    val d = inst(3)
                    val v1 = readR(s1)
                    val v2 = readR(s2)
                    val v = v1 + v2
                    writeR(d, v)
                    writeR('P', readR('P') + 2)
        case '-' => val s1 = inst(1)
                    val s2 = inst(2)
                    val d = inst(3)
                    val v1 = readR(s1)
                    val v2 = readR(s2)
                    val v = v1 - v2
                    writeR(d, v)
                    writeR('P', readR('P') + 2)
        case '*' => val s1 = inst(1)
                    val s2 = inst(2)
                    val d = inst(3)
                    val v1 = readR(s1)
                    val v2 = readR(s2)
                    val v = v1 * v2
                    writeR(d, v)
                    writeR('P', readR('P') + 2)
        case '/' => val s1 = inst(1)
                    val s2 = inst(2)
                    val d = inst(3)
                    val v1 = readR(s1)
                    val v2 = readR(s2)
                    val v = v1 / v2
                    writeR(d, v)
                    writeR('P', readR('P') + 2)
        case '%' => val s1 = inst(1)
                    val s2 = inst(2)
                    val d = inst(3)
                    val v1 = readR(s1)
                    val v2 = readR(s2)
                    val v = v1 % v2
                    writeR(d, v)
                    writeR('P', readR('P') + 2)
        // Branch Operands
        case 'B' => val s = inst(1)
                    val hh_hl = inst(2).toString + inst(3).toString
                    if (readR(s) != 0) {
                        writeR('P', readR('P') + readValue("0x" + hh_hl) * 2)
                    } else {
                        writeR('P', readR('P') + 2)
                    }
        case 'b' => val s = inst(1)
                    val hh_hl = inst(2).toString + inst(3).toString
                    if(readR(s) != 0) {
                        writeR('P', readR('P') - readValue("0x" + hh_hl) * 2)
                    } else {
                        writeR('P', readR('P') + 2)
                    }
        case 'E' => val s = inst(1)
                    val hh_hl = inst(2).toString + inst(3).toString
                    if(readR(s) == 0) {
                        writeR('P', readR('P') + readValue("0x" + hh_hl) * 2)
                    } else {
                        writeR('P', readR('P') + 2)
                    }
        case 'e' => val s = inst(1)
                    val hh_hl = inst(2).toString + inst(3).toString
                    if(readR(s) == 0) {
                        writeR('P', readR('P') - readValue("0x" + hh_hl) * 2)
                    } else {
                        writeR('P', readR('P') + 2)
                    }
        case '<' => val s = inst(1)
                    val hh_hl = inst(2).toString + inst(3).toString
                    if(readR(s) < 0) {
                        writeR('P', readR('P') + readValue("0x" + hh_hl) * 2)
                    } else {
                        writeR('P', readR('P') + 2)
                    }
        case 'l' => val s = inst(1)
                    val hh_hl = inst(2).toString + inst(3).toString
                    if(readR(s) < 0) {
                        writeR('P', readR('P') - readValue("0x" + hh_hl) * 2)
                    } else {
                        writeR('P', readR('P') + 2)
                    }
        case '>' => val s = inst(1)
                    val hh_hl = inst(2).toString + inst(3).toString
                    if(readR(s) > 0) {
                        writeR('P', readR('P') + readValue("0x" + hh_hl) * 2)
                    } else {
                        writeR('P', readR('P') + 2)
                    }
        case 'g' => val s = inst(1)
                    val hh_hl = inst(2).toString + inst(3).toString
                    if(readR(s) > 0) {
                        writeR('P', readR('P') - readValue("0x" + hh_hl) * 2)
                    } else {
                        writeR('P', readR('P') + 2)
                    }
        // Return
        case 'R' => val s = inst(1)
                    writeR('P', readR(s))
        case 'H' => halt = true
        // Jump and Imm
        case 'J' => val imm = readValue("0x" + readI(readR('P') + 2))
                    writeR(inst(1), readR('P') + 4)
                    writeR('P', imm)
        case 'I' => val imm = readValue("0x" + readI(readR('P') + 2))
                    writeR(inst(1), imm)
                    writeR('P', readR('P') + 4)
        // Syscall
        case '!' => val m = inst(1)
                    var a = readR(m)
                    val hh_hl = inst(2).toString + inst(3).toString
                    hh_hl match {
                        case "01" => {
                            while (readM(a) != 0) {
                                print(readM(a).toChar)
                                a += 1
                            }
                        }
                        case "02" => {
                            val scanner = new java.util.Scanner(System.in)
                            writeR(m, readValue(scanner.nextLine()))
                        }
                    }
                    writeR('P', readR('P') + 2)
        case _ => throw new IllegalArgumentException("Instruction not found.")
    }

    mode match {
        case "1" => println(f"I: $inst, R: ${new_regs.mkString("[", ", ", "]")}, M: ${new_mem.mkString("[", ", ", "]")}")
                /*
                Output a trace of execution that includes on each line the instruction executed,
                the new values of any registers changed by that instruction,
                and the address and value of any changed memory locations.
                */
        case "2" =>// is below
                /*
                Execute without tracing (faster) and output the values in each data section at the end of execution.
                Use the second value in each the data section header as the number of memory locations to display at the end.
                */
        case "3" => // perform syscall operands - if not mode 3, then don't do any syscalls

        case "4" =>
                /*
                Analyse the program by outputting all the read-after-write hazards in the program.
                For each one, output the addresses and pair of instructions.
                */
        case _ => throw new IllegalArgumentException("Not a valid mode.")
    }

    new_regs = List[Char]()
    new_mem  = List[(Int,Int)]()

} while (!halt)


if (mode == "2") {
    // output the values in each data section
    // truncated by the second number in the data header, if there is one
    for (d <- mem_trunc.toList.filter(_._2 != 0)) {
        var a = d._1
        print(f"Address: ${d._1}\nData:    ")
        if (d._2 != 0) {
            // print the data starting at a until d._2 is reached
            for (i <- 1 to d._2) {
                print(readM(a))
                a += 1
            }
            print('\n')
        }
    }
}
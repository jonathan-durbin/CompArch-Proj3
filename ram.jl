filename    = ARGS[1]
mode        = ARGS[2]
codeMode    = true
cur         = 0
mask        = 65535
mem         = Dict{Int16, Int16}()
mem_trunc   = Dict{Int, Int}()
regs        = Dict{Char, Int}()
new_regs    = Array{Char, 1}()
new_mem     = Array{Array{Int, 1}, 1}()
hazard      = tuple('0', '0', 0)  # (reg1, reg2, mem_location)


"Write the value v to an address a in memory."
function writeM(a:: Int, v:: Int16)
    mem[a] = v
    mode == "1" && push!(new_mem, Array{Int, 1}(a, mem[a]))
end

"Read from address a in memory, if address not present, return 0"
function readM(a:: Int16):: Int16
    get(mem, a, 0)
end

"Write the value v to register a if a is not a digit"
function writeR(a:: Char, v:: Int16)
    !('0' <= a <= '9') && (regs[a] = v)
    mode == "1" && push!(new_regs, a)
end

"Output the value in register a. Registers 0-9 only hold their values."
function readR(a:: Char):: Int
    '0' <= a <= '9' ?
        readValue(string(a)) :
        get(regs, a, 0)
end

"Read the instruction at address a. Return "
function readI(a:: Int16)
    x = readM(a)
    y = readM(a+1)
    t = [
        x & 0x00ff, x & 0xff00,
        y & 0x00ff, y & 0xff00
    ]
    String(map(x -> Char(x), t))
end

function readValue(a:: String)
    startswith(a, "0x") ?
        parse(Int, replace(a, "0x"=>""), base=16) :
        parse(Int, a, base=10)
end


stop = false
writeSeen = false
open(filename, "r") do file
    global codeMode, cur
    for line in readlines(file)
        stop && break
        if startswith(line, "code: ")
            address = split(replace(line, "code: "=>""))[1]
            println("Address: $address")
            cur = readValue(String(address))
            codeMode = true
        elseif startswith(line, "data: ")
            header = split(replace(line, "data: "=>""))
            cur = readValue(String(header[1]))
            trunc = length(header) == 2 ? readValue(header[2]) : 0
            mem_trunc(cur) = trunc
            codeMode = false
        else
            if codeMode
                code = rpad(strip(split(line, "#")[1]), 4)
                if code != "    "
                    writeM(
                        cur,   Int16(Int(code[1]) % 256
                            + (Int(code[2]) % 256) * 256)
                    )
                    writeM(
                        cur+1, Int16(Int(code[3]) % 256
                            + (Int(code[4]) % 256) * 256)
                    )
                    if mode == "4"
                        if !writeSeen
                            nothing
                        else
                            nothing
                        end
                    end
                    cur += 2
                end
            else
                data = map(
                    x -> readValue(String(x)),
                    split(strip(split(line, "#")[1]))
                )
                for d in data
                    writeM(cur, d)
                    cur += 1
                end
            end
        end
    end
end


# writeR('P', 0)
inst = ""
halt = false

while !halt
    inst = readI(readR('P'))
    c = inst[1]
    inst = lstrip(inst, c)

    if c == 'L'
        r = inst[1]
        d = inst[2]
        a = readR(r)
        v = readM(a)
        writeR(d, v)
        writeR('P', readR('P') + 2)

    elseif c == 'S'
        s = inst[1]
        w = inst[2]
        a = readR(w)
        v = readR(s)
        writeM(a, v)
        writeR('P', readR('P') + 2)

    # Mathematical operands
    elseif c == '+'
        s1 = inst[1]
        s2 = inst[2]
        d  = inst[3]
        v1 = readR(s1)
        v2 = readR(s2)
        v  = v1 + v2
        writeR(d, v)
        writeR('P', readR('P') + 2)

    elseif c == '-'
        s1 = inst[1]
        s2 = inst[2]
        d = inst[3]
        v1 = readR(s1)
        v2 = readR(s2)
        v = v1 - v2
        writeR(d, v)
        writeR('P', readR('P') + 2)

    elseif c == '*'
        s1 = inst[1]
        s2 = inst[2]
        d = inst[3]
        v1 = readR(s1)
        v2 = readR(s2)
        v = v1 * v2
        writeR(d, v)
        writeR('P', readR('P') + 2)

    elseif c == '/'
        s1 = inst[1]
        s2 = inst[2]
        d = inst[3]
        v1 = readR(s1)
        v2 = readR(s2)
        v = v1 / v2
        writeR(d, v)
        writeR('P', readR('P') + 2)

    elseif c == '%'
        s1 = inst[1]
        s2 = inst[2]
        d = inst[3]
        v1 = readR(s1)
        v2 = readR(s2)
        v = v1 % v2
        writeR(d, v)
        writeR('P', readR('P') + 2)

    # Branch operands
    elseif c == 'B'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) != 0 ?
            writeR('P', readR('P') + readValue("0x" + hh_hl) * 2) :
            writeR('P', readR('P') + 2)

    elseif c == 'b'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) != 0 ?
            writeR('P', readR('P') - readValue("0x" + hh_hl) * 2) :
            writeR('P', readR('P') + 2)

    elseif c == 'E'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) == 0 ?
            writeR('P', readR('P') + readValue("0x" + hh_hl) * 2) :
            writeR('P', readR('P') + 2)

    elseif c == 'e'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) == 0 ?
            writeR('P', readR('P') - readValue("0x" + hh_hl) * 2) :
            writeR('P', readR('P') + 2)

    elseif c == '<'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) < 0 ?
            writeR('P', readR('P') + readValue("0x" + hh_hl) * 2) :
            writeR('P', readR('P') + 2)

    elseif c == 'l'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) < 0 ?
            writeR('P', readR('P') - readValue("0x" + hh_hl) * 2) :
            writeR('P', readR('P') + 2)

    elseif c == '>'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) > 0 ?
            writeR('P', readR('P') + readValue("0x" + hh_hl) * 2) :
            writeR('P', readR('P') + 2)

    elseif c == 'g'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) > 0 ?
            writeR('P', readR('P') - readValue("0x" + hh_hl) * 2) :
            writeR('P', readR('P') + 2)

    # Return and halt
    elseif c == 'R'
        writeR('P', readR(inst[1]))

    elseif c == 'H'
        halt = true

    # Jump and Imm
    elseif c == 'J'
        imm = readValue("0x" * readI(readR('P') + 2))
        writeR(inst[1], readR('P') + 4)
        writeR('P', imm)

    elseif c == 'I'
        imm = readValue("0x" * readI(readR('P') + 2))
        writeR(inst[1], imm)
        writeR('P', readR('P') + 4)

    # Syscall
    elseif c == '!'
        m = inst[1]
        a = readR(m)
        hh_hl = inst[2] * inst[3]
        if hh_hl == "01"
            while readM(a) != 0
                print(Char(readM(a)))
                a += 1
            end
        elseif hh_hl == "02"
            writeR(m, readValue(readline(stdin)))
        end
        writeR('P', readR('P') + 2)
    else
        @error("Illegal instruction!")
        break
    end

    println(inst)

    if mode == "1" println("$inst, R: $new_regs, M: $new_mem")
    elseif !(mode in ["2", "3", "4"]) error("Not a valid mode!")
    end

    new_regs = Array{Char}()
    new_mem  = Array{Array{Int, Int}, 1}()
end  # execution block

# println(regs)
if mode == "2"
    nothing
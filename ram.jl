filename    = ARGS[1]
mode        = ARGS[2]
codeMode    = true
cur         = 0
mask        = 65535
mem         = Dict{Int, Int}()
mem_trunc   = Dict{Int, Int}()
regs        = Dict{Char, Int}()
new_regs    = Array{Char}()
new_mem     = Array{Array{Int, Int}, 1}()
hazard      = tuple('0', 0)

function writeM(a:: Int, v:: Int)
    get!(mem, a, v & mask)
    mode == "1" && push!(new_mem, Array(a, mem[a]))
end

function readM(a:: Int)
    get(mem, a, 0)
end

function writeR(a:: Char, v:: Int)
    !('0' <= a <= '9') && get!(regs, a, v)
    mode == "1" && push!(new_regs, a)
    mode == "4" && a != 'P' && hazard = tuple(a, readR('P'))
end

function readR(a:: Char)
    '0' <= a <= '9' ?
        readValue(String(a)) :
        get(regs, a, 0)
end

function readI(a:: Int)
    x = readM(a)
    y = readM(a+1)
    t = [
        x & 0xff, (x >> 8) & 0xff,
        y & 0xff, (y >> 8) & 0xff
    ]
    String(map(x -> Char(x), t))
end

function readValue(a:: String)
    startswith(a, "0x") ?
        parse(Int, replace(a, "0x"=>""), base=16) :
        parse(Int, a, base=10)
end

open(filename, "r") do file
    global codeMode, cur
    for line in readlines(file)
        if startswith(line, "code: ")
            address = split(replace(line, "code: "=>""))[1]
            println("Address: $address")
            cur = readValue(String(address))
            codeMode = true
        elseif startswith(line, "data: ")
            address = split(replace(line, "data: "=>""))[1]
            cur = readValue(String(address))
            codeMode = false
        else
            if codeMode
                code = rpad(strip(split(line, "#")[1]), 4)
                if code != "    "
                    writeM(
                        cur,   Int(code[1]) % 256
                            + (Int(code[2]) % 256) * 256
                    )
                    writeM(
                        cur+1, Int(code[3]) % 256
                            + (Int(code[4]) % 256) * 256
                    )
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


writeR('P', 0)
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
        s = inst[1]
        writeR('P', readR(s))

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
    # inst == "H   " && break
end

println(regs)
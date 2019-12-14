filename    = ARGS[1]
mode        = ARGS[2]
codeMode    = true
cur         = Int16(0)
mem         = Dict{Int16, Int16}()
mem_trunc   = Dict{Int16, Int}()
regs        = Dict{Char, Int}()
new_regs    = Array{Char, 1}()
new_mem     = Array{Array{Int16, 1}, 1}()


"Write the value v to an address a in memory."
function writeM(a:: Int16, v:: Int16)
    mem[a] = v
    mode == "1" && push!(new_mem, Int16[a, mem[a]])
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
function readR(a:: Char):: Int16
    '0' <= a <= '9' ?
        readValue(string(a)) :
        get(regs, a, Int16(0))
end

"Return the instruction at address a. Only usable once instructions are loaded into memory."
function readI(a:: Int16):: String
    x = readM(a)
    y = readM(a+Int16(1))
    t = [
        x & 0xff, (x >> 8) & 0xff,
        y & 0xff, (y >> 8) & 0xff
    ]
    String(map(x -> Char(x), t))
end

"Return the value `a` as an Int16. `a` can be hex (i.e., 0x1234) or dec (i.e., 1234)."
function readValue(a:: String):: Int16
    startswith(a, "0x") ?
        parse(Int16, replace(a, "0x"=>""), base=16) :
        parse(Int16, a, base=10)
end
readValue(a:: SubString{String}) = readValue(string(a))


destReg = " "
lastInst = ""
println("Opening $filename, loading into memory.")
open(filename, "r") do file
    global codeMode, cur
    for line in readlines(file)
        if startswith(line, "code: ")
            address = split(replace(line, "code: "=>""))[1]
            cur = readValue(String(address))
            codeMode = true
        elseif startswith(line, "data: ")
            header = split(replace(line, "data: "=>""))
            cur = readValue(String(header[1]))
            trunc = length(header) == 2 ? readValue(header[2]) : 0
            mem_trunc[cur] = Int(trunc)
            codeMode = false
        else
            if codeMode
                code = rpad(strip(split(line, "#")[1]), 4)
                if code != "    "
                    # println(code)
                    writeM(
                        cur,   Int16(code[1]) % Int16(256)
                            + (Int16(code[2]) % Int16(256)) * Int16(256)
                    )
                    writeM(
                        cur+Int16(1), Int16(code[3]) % Int16(256)
                            + (Int16(code[4]) % Int16(256)) * Int16(256)
                    )
                    if mode == "4"
                        errString = "Hazard: $lastInst, $code"
                        if code[1] in "BbEe<l>g"  # branches
                            destReg in "$(code[2])" && println(errString)
                            destReg = " "
                            lastInst = code
                        elseif code[1] in "+-*/%"  # maths
                            destReg in "$(code[2])$(code[3])" && println(errString)
                            destReg = string(code[4])
                            lastInst = code
                        elseif code[1] in "JI"  # jumps/immediates
                            destReg = string(code[2])
                            lastInst = code
                        elseif '!' == code[1]  # syscalls
                            destReg in "$(code[2])" && println(errString)
                            destReg = string(code[2])
                            lastInst = code
                        elseif 'L' == code[1]  # loads
                            destReg in "$(code[2])" && println(errString)
                            destReg = string(code[3])
                            lastInst = code
                        elseif 'R' == code[1]  # returns
                            destReg in "$(code[2])" && println(errString)
                            destReg = " "
                            lastInst = code
                        end
                    end
                    cur += Int16(2)
                end
            else
                data = map(
                    x -> readValue(String(x)),
                    split(strip(split(line, "#")[1]))
                )
                for d in data
                    writeM(cur, d)
                    cur += Int16(1)
                end
            end
        end
    end
end


# writeR('P', 0)
halt = false
println("Executing memory.")
while !halt
    global new_regs, new_mem, halt
    inst = readI(readR('P'))
    # println(inst)
    c = inst[1]
    inst = lstrip(inst, c)

    if c == 'L'
        r = inst[1]
        d = inst[2]
        a = readR(r)
        v = readM(a)
        writeR(d, v)
        writeR('P', readR('P') + Int16(2))

    elseif c == 'S'
        s = inst[1]
        w = inst[2]
        a = readR(w)
        v = readR(s)
        writeM(a, v)
        writeR('P', readR('P') + Int16(2))

    # Mathematical operands
    elseif c == '+'
        s1 = inst[1]
        s2 = inst[2]
        d  = inst[3]
        v1 = readR(s1)
        v2 = readR(s2)
        v  = v1 + v2
        writeR(d, v)
        writeR('P', readR('P') + Int16(2))

    elseif c == '-'
        s1 = inst[1]
        s2 = inst[2]
        d = inst[3]
        v1 = readR(s1)
        v2 = readR(s2)
        v = v1 - v2
        writeR(d, v)
        writeR('P', readR('P') + Int16(2))

    elseif c == '*'
        s1 = inst[1]
        s2 = inst[2]
        d = inst[3]
        v1 = readR(s1)
        v2 = readR(s2)
        v = v1 * v2
        writeR(d, v)
        writeR('P', readR('P') + Int16(2))

    elseif c == '/'
        s1 = inst[1]
        s2 = inst[2]
        d = inst[3]
        v1 = readR(s1)
        v2 = readR(s2)
        v = v1 / v2
        writeR(d, v)
        writeR('P', readR('P') + Int16(2))

    elseif c == '%'
        s1 = inst[1]
        s2 = inst[2]
        d = inst[3]
        v1 = readR(s1)
        v2 = readR(s2)
        v = v1 % v2
        writeR(d, v)
        writeR('P', readR('P') + Int16(2))

    # Branch operands
    elseif c == 'B'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) != 0 ?
            writeR('P', readR('P') + readValue("0x" * hh_hl) * Int16(2)) :
            writeR('P', readR('P') + Int16(2))

    elseif c == 'b'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) != 0 ?
            writeR('P', readR('P') - readValue("0x" * hh_hl) * Int16(2)) :
            writeR('P', readR('P') + Int16(2))

    elseif c == 'E'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) == 0 ?
            writeR('P', readR('P') + readValue("0x" * hh_hl) * Int16(2)) :
            writeR('P', readR('P') + Int16(2))

    elseif c == 'e'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) == 0 ?
            writeR('P', readR('P') - readValue("0x" * hh_hl) * Int16(2)) :
            writeR('P', readR('P') + Int16(2))

    elseif c == '<'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) < 0 ?
            writeR('P', readR('P') + readValue("0x" * hh_hl) * Int16(2)) :
            writeR('P', readR('P') + Int16(2))

    elseif c == 'l'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) < 0 ?
            writeR('P', readR('P') - readValue("0x" * hh_hl) * Int16(2)) :
            writeR('P', readR('P') + Int16(2))

    elseif c == '>'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) > 0 ?
            writeR('P', readR('P') + readValue("0x" * hh_hl) * Int16(2)) :
            writeR('P', readR('P') + Int16(2))

    elseif c == 'g'
        s = inst[1]
        hh_hl = inst[2] * inst[3]
        readR(s) > 0 ?
            writeR('P', readR('P') - readValue("0x" * hh_hl) * Int16(2)) :
            writeR('P', readR('P') + Int16(2))

    # Return and halt
    elseif c == 'R'
        writeR('P', readR(inst[1]))

    elseif c == 'H'
        halt = true

    # Jump and Imm
    elseif c == 'J'
        imm = readValue("0x" * readI(readR('P') + Int16(2)))
        writeR(inst[1], readR('P') + Int16(4))
        writeR('P', imm)

    elseif c == 'I'
        imm = readValue("0x" * readI(readR('P') + Int16(2)))
        writeR(inst[1], imm)
        writeR('P', readR('P') + Int16(4))

    # Syscall
    elseif c == '!'
        m = inst[1]
        a = readR(m)
        hh_hl = inst[2] * inst[3]
        if hh_hl == "01"
            while readM(a) != 0
                print(Char(readM(a)))
                a += Int16(1)
            end
        elseif hh_hl == "02"
            writeR(m, readValue(readline(stdin)))
        end
        writeR('P', readR('P') + Int16(2))
    else
        @error("Illegal instruction!")
        break
    end

    ms = !isempty(new_mem) ? ", M: " * string(new_mem) : ""
    rs = !isempty(new_regs) ? ", R: " * string(new_regs) : ""
    if mode == "1" println("$(c * inst)" * rs * ms)
    elseif !(mode in ["2", "3", "4"]) error("Not a valid mode!")
    end

    new_regs = Array{Char, 1}()
    new_mem  = Array{Array{Int16, 1}, 1}()
end  # execution block

# println(regs)
# println(mem_trunc)
if mode == "2"
    # output the values in each data section
    for d in sort(collect(mem_trunc))
        a = d[1]
        print("Address: $(d[1])\nData:    ")
        if d[2] != 0
            for i = 1:d[2]
                print(readM(a))
                a += Int16(1)
            end
            print('\n')
        end
    end
end


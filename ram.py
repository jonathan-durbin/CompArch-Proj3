import sys

filename = sys.argv[1]
codeMode = True
cur = 0
mem = {}
regs = {}

def writeM(a, v):
    mem[a] = v

def readM(a):
    return mem.get(a, 0)

def writeR(a, v):
    assert(len(a) == 1)
    if not ('0' <= a and a <= '9'):
        regs[a] = v

def readR(a):
    if '0' <= a and a <= '9':
        return int(a)
    return regs.get(a, 0)

def readI(a):
    # read instruction at address `a`
    x, y = readM(a), readM(a+1)
    return "".join(map(chr, [x & 0xff, (x >> 8) & 0xff, y & 0xff, (y >> 8) & 0xff]))

with open(filename) as f:
    for l in f.readlines():
        if l.startswith("code: "):
            address = l[6:].split(" ")[0]
            cur = int(address, 0)
            codeMode = True
        elif l.startswith("data: "):
            address = l[6:].split(" ")[0]
            cur = int(address, 0)
            codeMode = False
        else:
            if codeMode:
                code = l.split("#")[0].strip().ljust(4)
                if code != "    ":
                    writeM(cur,   ord(code[0]) + ord(code[1])*256)
                    writeM(cur+1, ord(code[2]) + ord(code[3])*256)
                    cur = cur + 2
            else:
                vs = map(lambda x: int(x, 0),
                    filter(lambda x: x != "",
                        l.split("#")[0].strip().split(" ")))
                for v in vs:
                    writeM(cur, v)
                    cur = cur + 1

cur = 0
while True:
    pc = readR('P')
    inst = readI(pc)

    if inst[0] == 'I':
        imm = int('0x' + readI(pc+2), 0)
        writeR(inst[1], imm)
        writeR('P', pc + 4)

    elif inst[0] == 'L':
        r = inst[1]
        d = inst[2]
        a = readR(r)
        v = readM(a)
        writeR(d, v)
        writeR('P', pc+2)
    elif inst[0] == '+':
        s1 = inst[1]
        s2 = inst[2]
        d  = inst[3]
        v1 = readR(s1)
        v2 = readR(s2)
        v  = v1 + v2
        writeR(d, v)
        writeR('P', pc+2)
    # elif inst[0] ==
    # elif inst[0] ==
    # elif inst[0] ==
    else:
        raise Exception('Illegal instruction!')

    print(inst)
    if inst == "H   ":
        break


print(regs)
// To compile, do `dmd md4.d` (optionally with the -m64 flag).
// To unittest, compile with the flags `-main -unittest`.
// To debug, compile with the flag `-version=DebugMD4`.
module md4;

struct MD4Context
{
    uint[4] hash;
    uint[16] block;
    ulong byteCount;
}

ubyte[MD4Context.hash.sizeof] md4Of(scope const(ubyte)[] input)
{
    MD4Context context = md4CreateContext();
    md4Update(&context, input);
    return md4Final(&context);
}
unittest
{
    static string md4(string input)
    {
        import std.digest : toHexString, LetterCase;
        import std.string : representation;
        return md4Of(input.representation).toHexString!(LetterCase.lower).idup;
    }

    assert(md4("") == "31d6cfe0d16ae931b73c59d7e0c089c0");
    assert(md4("a") == "bde52cb31de33e46245e05fbdbd6fb24");
    assert(md4("abc") == "a448017aaf21d8525fc10ae87aa6729d");
    assert(md4("message digest") == "d9130a8164549fe818874806e1c7014b");
    assert(md4("abcdefghijklmnopqrstuvwxyz") == "d79e1c308aa5bbcdeea8ed63df412da9");
    assert(md4("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") == "043f8582f241db351ce627e153e7f0e4");
    assert(md4("12345678901234567890123456789012345678901234567890123456789012345678901234567890") == "e33b4ddc9c38f2199c3e7b164fcc0536");
}

MD4Context md4CreateContext()
{
    MD4Context context;
    md4ResetContext(&context);
    return context;
}

void md4ResetContext(MD4Context* context)
{
    with (context)
    {
        hash[0] = 0x67452301;
        hash[1] = 0xefcdab89;
        hash[2] = 0x98badcfe;
        hash[3] = 0x10325476;
        byteCount = 0;
    }
}

void md4Update(MD4Context* context, scope const(ubyte)[] data)
{
    version(DebugMD4)
    {
        import std.stdio;
        import std.digest : toHexString, LetterCase;
        writefln(`Updating with "%s" (%s)`, 
            cast(const(char)[]) data,
            data.toHexString!(LetterCase.lower));
    }
    const currentByteIndex   = cast(size_t)(context.byteCount & (context.block.sizeof - 1));
    const availableByteCount = context.block.sizeof - currentByteIndex;
    ubyte[] blockBytes       = cast(ubyte[]) context.block[];

    context.byteCount += data.length;

    if (availableByteCount > data.length)
    {
        blockBytes[currentByteIndex .. currentByteIndex + data.length] = data[];
        return;
    }

    blockBytes[currentByteIndex .. $] = data[0 .. availableByteCount];
    md4TransformWithLittleEndianConversion(context);
    data = data[availableByteCount .. $];
    
    while (data.length >= context.block.sizeof)
    {
        blockBytes[] = data[0 .. context.block.sizeof];
        md4TransformWithLittleEndianConversion(context);
        data = data[context.block.sizeof .. $];
    }

    blockBytes[0 .. data.length] = data[];
}

ubyte[MD4Context.hash.sizeof] md4Final(MD4Context* context)
{
    // Two cases:
    // if (stuff.length + 1 < until_the_last_two_bytes)
    //      MD4([ ...stuff, 0x80, ...0, byteCount[0], byteCount[1] ])
    // else // 
    //      MD4([ ...stuff, 0x80, ...0])
    ///     MD4([ ...0, byteCount[0], byteCount[1]]) 

    scope(exit)
        context.hash[] = 0;

    const lastTwoWordsIndex = context.block.sizeof - (uint[2]).sizeof;
    // The padding is a 0x80 followed by zeros.
    const paddingStartIndex = context.byteCount & (context.block.sizeof - 1);
    const zerosStartIndex   = paddingStartIndex + 1;
    ubyte[] blockBytes      = cast(ubyte[]) context.block[];

    blockBytes[paddingStartIndex] = 0x80;

    // the byte count (the last 8 bytes) does not fit
    if (paddingStartIndex >= lastTwoWordsIndex)
    {
        blockBytes[zerosStartIndex .. $] = 0;
        
        // do md4
        md4TransformWithLittleEndianConversion(context);

        blockBytes[0 .. lastTwoWordsIndex] = 0;
    }

    // the byte count fits
    else // if (zerosStartIndex <= lastTwoBytesIndex)
    {
        blockBytes[zerosStartIndex .. lastTwoWordsIndex] = 0;
    }

    // do md4
    context.block[14] = cast(uint) (context.byteCount << 3);
    context.block[15] = cast(uint) (context.byteCount >> 29);

    littleEndianToNativeAll(context.block[0 .. $ - 2]);
    md4Transform(context.hash, context.block);

    return cast(ubyte[context.hash.sizeof]) context.hash;
}

private void md4Transform(ref uint[4] hash, in uint[16] state)
{
    uint[4] temp = hash;
    ref uint a() { return temp[0]; }
    ref uint b() { return temp[1]; }
    ref uint c() { return temp[2]; }
    ref uint d() { return temp[3]; }

    static uint leftShiftRotate(uint x, uint s)
    {
        return (x << s) | (x >> (32 - s));
    }

    version(DebugMD4)
    {
        import std.stdio;
        import std.digest : toHexString, LetterCase;
        import std.algorithm;
        import std.conv;
        import std.range;
        import std.format : format;

        // writeln("Transform state vector:\n", 
        //     state[].map!(
        //         a => (cast(ubyte[])(&a)[0 .. 1])
        //             .toHexString!(LetterCase.lower)
        //             .idup)
        //     .joiner("\n"));
        writeln("Hash before transform: ", (cast(ubyte[]) hash[]).toHexString!(LetterCase.lower));
        scope(exit)
            writeln("Hash after transform: ", (cast(ubyte[]) hash[]).toHexString!(LetterCase.lower), "\n");

        enum bool hex = false; // false means binary 
        enum numCharsPerUint = hex ? 8 : 8 * 4;
        {
            enum headerFormatString = "%-8s " ~ text("%-", numCharsPerUint, "s").repeat(4).join(" ");
            // writefln(headerFormatString, "counter", "a", "b", "c", "d");
        }
        int counter = 0;
        
        void doDebug()
        {
            enum roundFormatString = "%-8d " ~ text("%0", numCharsPerUint, hex ? "x" : "b").repeat(4).join(" ");
            import std.bitmanip : nativeToLittleEndian;
            static uint s(uint a) 
            {
                // auto t = nativeToLittleEndian(a);
                // return *cast(uint*)&t;
                return a;
            }
            writefln(roundFormatString, counter, s(a), s(b), s(c), s(d));
            counter++;
        }

        enum string singleUintFormat = "%08b".repeat(4).join(`\\:`);
        static string formatUint(uint num)
        {
            ubyte[4] bytes = *cast(ubyte[4]*)&num;
            import std.format;
            return format(singleUintFormat, bytes[3], bytes[2], bytes[1], bytes[0]);
        }
        string formatTemp(size_t index)
        {
            return formatUint(temp[index]);
        }

        {
            writeln();
            enum string arrowFormat = `%s \rightarrow %s`;
            enum string formatString = `$ ` ~ arrowFormat.repeat(4).join(`; \\\\` ~ "\n") ~ `. $`;
            writefln(formatString,
                "A", formatTemp(0),
                "B", formatTemp(1),
                "C", formatTemp(2),
                "D", formatTemp(3));
            writeln();
        }
    }

    enum size_t[4][4] indexPermutationForInnerIteration = 
    [
        [ 0, 1, 2, 3 ],
        [ 3, 0, 1, 2 ],
        [ 2, 3, 0, 1 ],
        [ 1, 2, 3, 0 ],
    ];

    enum size_t[4][3] constantStateOffsets = [
        [ 0, 4, 8, 12 ],
        [ 0, 1, 2, 3  ],
        [ 0, 2, 1, 3  ],
    ];

    enum size_t[4][3] variableStateOffsets = [
        [ 0, 1, 2, 3  ],
        [ 0, 4, 8, 12 ],
        [ 0, 8, 4, 12 ],
    ];

    enum uint[4][3] shifts = [
        [ 3, 7, 11, 19 ],
        [ 3, 5, 9,  13 ],
        [ 3, 9, 11, 15 ],
    ];

    version (DebugMD4)
    {
        static string latexFormatFunctionInvocation(size_t roundIndex, string x, string y, string z)
        {
            // the hax omg
            // immutable string[3] formulas = [
            //     `(%1$s \land %2$s) \lor %4$s \lor (\lnot %1$s \land %3$s)`,
            //     `(%1$s \land %2$s) \lor %4$s \lor (%1$s \and %3$s) \lor %4$s \lor (%2$s \land %3$s)`,
            //     `%1$s \oplus %2$s \oplus %3$s %4$s`,
            // ];
            // return formulas[roundIndex].format(x, y, z, lastArg);

            bool shouldBreak = (x.length + y.length + z.length > 30 && roundIndex != 2);
            switch (roundIndex)
            {
                case 0:
                    return text(`(`, x, ` \land `, y, `) %s (\lnot `, x, ` \land `, z, `)`)
                        .format(shouldBreak ?  `\lor \\\\ \lor ` : `\lor`); 

                case 1:
                    return text(`(`, x, ` \land `, y, `) %1$s (`, x, ` \land `, z, `) %1$s (`, y, ` \land `, z, `)`)
                        .format(shouldBreak ?  `\lor \\\\ \lor ` : `\lor`); 
                case 2:
                    return `%s \oplus %s \oplus %s`.format(x, y, z);

                default: assert(0);
            }
        }
    }

    static uint F(uint x, uint y, uint z)
    {
        return (x & y) | ((~x) & z);
    }
    static uint G(uint x, uint y, uint z)
    {
        return (x & y) | (x & z) | (y & z);
    }
    static uint H(uint x, uint y, uint z)
    {
        return x ^ y ^ z;
    }
    import std.meta : AliasSeq;
    alias functions = AliasSeq!(F, G, H);

    enum uint[3] M = [0, 0x5A827999, 0x6ED9EBA1];


    // Why do this? because then logging debug messages is way easier.
    static foreach (roundIndex; 0 .. 3)
    {
        version(DebugMD4)
        {
            writefln("Starting round $ %d $. $ %s(x, y, z) = %s $.\n",
                roundIndex,
                __traits(identifier, functions[roundIndex]),
                latexFormatFunctionInvocation(roundIndex, "x", "y", "z"));
        }

        static foreach (outerIterationIndex, constantStateOffset; constantStateOffsets[roundIndex])
        {
            static foreach (innerIterationIndex, variableStateOffset; variableStateOffsets[roundIndex])
            {{
                enum perm  = indexPermutationForInnerIteration[innerIterationIndex];
                enum shift = shifts[roundIndex][innerIterationIndex];

                uint k          = state[constantStateOffset + variableStateOffset];
                uint funcResult = functions[roundIndex](temp[perm[1]], temp[perm[2]], temp[perm[3]]);
                uint sumResult  = temp[perm[0]] + funcResult + k + M[roundIndex];
                uint rotated    = leftShiftRotate(sumResult, shift);

                version(DebugMD4)
                // static if (roundIndex == 2)
                {
                    writeln();
                    writefln("Global iteration $ %d / 48 $, Round iteration $ %d / 16 $.",
                        ++counter,
                        outerIterationIndex * 4 + innerIterationIndex + 1);
                    writeln();

                    static string getName(size_t index)
                    {
                        return ["A", "B", "C", "D"][index];
                    }

                    {
                        enum string formatString = `1\. $ %s = `
                            ~ "%s"
                            ~ ` = \\\\ = `
                            ~ "%s"
                            ~ ` = \\\\ = %s. $` ~ "\n";

                        writefln(formatString,
                            __traits(identifier, functions[roundIndex]),
                            latexFormatFunctionInvocation(roundIndex, getName(1), getName(2), getName(3)),
                            latexFormatFunctionInvocation(roundIndex, formatTemp(perm[1]), formatTemp(perm[2]), formatTemp(perm[3])),
                            formatUint(funcResult));
                    }
                    {
                        static string mod(string f)
                        {
                            return `(` ~ f ~ `) \mod 2 ^ {32}`;
                        }
                        enum string formatString = `2\. $ `
                            ~ mod(`%s + %s + k + M`)
                            ~ ` = \\\\ =`
                            ~ mod(`%s + %s + \\\\ + \\: %s + %s`)
                            ~ ` = \\\\ =`
                            ~ mod(`%d + %d + %d + %d`)
                            ~ ` = \\\\ = %d (%s). $` ~ "\n";
                            
                        writefln(formatString,
                            getName(0), __traits(identifier, functions[roundIndex]),
                            formatTemp(perm[0]), formatUint(funcResult), formatUint(k), formatUint(M[roundIndex]),
                            temp[perm[0]], funcResult, k, M[roundIndex],
                            sumResult, formatUint(sumResult));
                    }
                    {
                        writefln(`3\. $ %s \lll %d = %s. $` ~ "\n",
                            formatUint(sumResult),
                            shift,
                            formatUint(rotated));
                    }
                    {
                        enum string reorderFormat = `%s \rightarrow %s \rightarrow %s`;
                        enum string allReorderFormat = reorderFormat.repeat(4).join(`; \\\\` ~ "\n");
                        writefln(`4\. $ ` ~ allReorderFormat ~ ". $\n",
                            "D", "A", formatTemp(perm[3]),
                            "A", "B", formatUint(rotated),
                            "B", "C", formatTemp(perm[1]),
                            "C", "D", formatTemp(perm[2]));
                    }
                    writeln();
                    writeln();
                }

                temp[perm[0]] = rotated;
            }}
        }
    }

    hash[] += temp[];
}


private void littleEndianToNativeAll(uint[] arr)
{
    import std.bitmanip : littleEndianToNative;
    foreach (ref ubyte[4] b; cast(ubyte[4][]) arr)
        *(cast(uint*)&b) = littleEndianToNative!uint(b);
}

private void md4TransformWithLittleEndianConversion(MD4Context* context)
{
    littleEndianToNativeAll(context.block[]);
    md4Transform(context.hash, context.block);
}

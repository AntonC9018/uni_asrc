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

        writeln("Transform state vector:\n", 
            state[].map!(
                a => (cast(ubyte[])(&a)[0 .. 1])
                    .toHexString!(LetterCase.lower)
                    .idup)
            .joiner("\n"));
        writeln("Hash before transform: ", (cast(ubyte[]) hash[]).toHexString!(LetterCase.lower));
        scope(exit)
            writeln("Hash after transform: ", (cast(ubyte[]) hash[]).toHexString!(LetterCase.lower), "\n");

        enum bool hex = false; // false means binary 
        enum numCharsPerUint = hex ? 8 : 8 * 4;
        {
            enum headerFormatString = "%-8s " ~ text("%-", numCharsPerUint, "s").repeat(4).join(" ");
            writefln(headerFormatString, "counter", "a", "b", "c", "d");
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
        doDebug();
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

    static uint FF(uint a, uint b, uint c, uint d, uint k, uint s)
    {
        static uint F(uint x, uint y, uint z)
        {
            return (x & y) | ((~x) & z);
        }
        return leftShiftRotate(a + F(b, c, d) + k, s);
    }

    static uint GG(uint a, uint b, uint c, uint d, uint k, uint s)
    {
        static uint G(uint x, uint y, uint z)
        {
            return (x & y) | (x & z) | (y & z);
        }
        return leftShiftRotate(a + G(b, c, d) + k + cast(uint) 0x5A827999, s);
    }

    static uint HH(uint a, uint b, uint c, uint d, uint k, uint s)
    {
        static uint H(uint x, uint y, uint z)
        {
            return x ^ y ^ z;
        }
        return leftShiftRotate(a + H(b, c, d) + k + cast(uint) 0x6ED9EBA1, s);
    }

    import std.meta : AliasSeq;
    alias functions = AliasSeq!(FF, GG, HH);

    // Why do this? because then logging debug messages is way easier.
    static foreach (roundIndex; 0 .. 3)
    {
        static foreach (outerIterationIndex, constantStateOffset; constantStateOffsets[roundIndex])
        {
            static foreach (innerIterationIndex, variableStateOffset; variableStateOffsets[roundIndex])
            {{
                enum perm  = indexPermutationForInnerIteration[innerIterationIndex];
                enum shift = shifts[roundIndex][innerIterationIndex];

                temp[perm[0]] = functions[roundIndex](
                    temp[perm[0]], temp[perm[1]], temp[perm[2]], temp[perm[3]],
                    state[constantStateOffset + variableStateOffset],
                    shift);

                version(DebugMD4)
                    doDebug();
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

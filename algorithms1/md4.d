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
    uint a = hash[0];
    uint b = hash[1];
    uint c = hash[2];
    uint d = hash[3];

    version(DebugMD4)
    {
        import std.stdio;
        import std.digest : toHexString, LetterCase;
        import std.algorithm;
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

        writefln("%-8s %-8s %-8s %-8s %-8s", "counter", "a", "b", "c", "d");
        int counter = 0;

        
        void doDebug()
        {
            writefln("%-8d %08x %08x %08x %08x", counter, a, b, c, d);
            counter++;
        }
        doDebug();
    }

    uint leftShiftRotate(uint x, uint s)
    {
        return (x << s) | (x >> (32 - s));
    }

    {
        uint F(uint x, uint y, uint z)
        {
            return (x & y) | ((~x) & z);
        }
        void FF(ref uint a, uint b, uint c, uint d, uint k, uint s)
        {
            a = leftShiftRotate(a + F(b, c, d) + k, s);
            version(DebugMD4)
                doDebug();
        }
        static foreach (iterCount; [cast(size_t) 0, 4, 8, 12])
        {
            FF(a, b, c, d, state[0 + iterCount], 3);
            FF(d, a, b, c, state[1 + iterCount], 7);
            FF(c, d, a, b, state[2 + iterCount], 11);
            FF(b, c, d, a, state[3 + iterCount], 19);
        }

        // static foreach (iterCount; [cast(size_t) 0, 4, 8, 12])
        // static foreach (index, shift; [cast(uint) 3, 7, 11, 19])
        // {
        //     FF(
        //         v[index % 4],
        //         v[(index + 1) % 4],
        //         v[(index + 2) % 4],
        //         v[(index + 3) % 4],
        //         state[index + iterCount],
        //         shift);
        // }
    }
    {
        uint G(uint x, uint y, uint z)
        {
            return (x & y) | (x & z) | (y & z);
        }
        void GG(ref uint a, uint b, uint c, uint d, uint k, uint s)
        {
            a = leftShiftRotate(a + G(b, c, d) + k + cast(uint) 0x5A827999, s);
            version(DebugMD4)
                doDebug();
        }
        static foreach (iterCount; 0 .. 4)
        {
            GG(a, b, c, d, state[0  + iterCount], 3);
            GG(d, a, b, c, state[4  + iterCount], 5);
            GG(c, d, a, b, state[8  + iterCount], 9);
            GG(b, c, d, a, state[12 + iterCount], 13);
        }
    }
    {
        uint H(uint x, uint y, uint z)
        {
            return x ^ y ^ z;
        }
        void HH(ref uint a, uint b, uint c, uint d, uint k, uint s)
        {
            a = leftShiftRotate(a + H(b, c, d) + k + cast(uint) 0x6ED9EBA1, s);
            version(DebugMD4)
                doDebug();
        }
        static foreach (iterCount; [cast(size_t) 0, 2, 1, 3])
        {
            HH(a, b, c, d, state[0  + iterCount], 3);
            HH(d, a, b, c, state[8  + iterCount], 9);
            HH(c, d, a, b, state[4  + iterCount], 11);
            HH(b, c, d, a, state[12 + iterCount], 15);
        }
    }

    hash[0] += a;
    hash[1] += b;
    hash[2] += c;
    hash[3] += d;
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

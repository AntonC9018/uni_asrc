import md4;

void main()
{
    import std.stdio;
    import std.digest : toHexString, LetterCase;
    import std.string : representation;
    writeln(md4Of("AChelloworld?123".representation).toHexString!(LetterCase.lower));
}
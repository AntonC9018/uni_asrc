void main()
{
    writeln("\nDiffie-Hellman");
    diffieHellman();

    writeln("\nDiffie-Hellman (matrix)");
    diffieHellmanMatrix();

    writeln("\nBlom");
    bool shouldGenerateNumbersRandomly = true;
    blom(shouldGenerateNumbersRandomly);
}

import std.math : powmod;
import std.random : uniform;
import std.stdio : writeln, writefln;
import std.numeric : lcm, gcd;

void diffieHellman()
{
    ulong p = 23;
    ulong alpha = 11;
    ulong x = 3;
    ulong y = 5;

    assert(gcd(alpha, p) == 1);

    ulong message1 = powmod(alpha, x, p);
    writeln("1st message A -> B: ", message1);

    ulong message2 = powmod(alpha, y, p);
    writeln("2nd message B -> A: ", message2);

    ulong k_A = powmod(message2, x, p);
    ulong k_B = powmod(message1, y, p);
    
    writeln("k = ", k_A);
    // writeln("k = ", k_B);
    assert(k_A == k_B);
}


T[N] matmul(T, size_t N, size_t M)(in T[N][M] matrix, in T[M] vector)
{
    T[N] result = 0;
    foreach (i; 0 .. N)
    foreach (j; 0 .. M)
    {
        result[i] += vector[j] * matrix[i][j];
    }
    
    // foreach (j; 0 .. M)
    //     result[] += vector[j] * matrix[][j];

    return result;
}

T dot(T, size_t N)(in T[N] v1, in T[N] v2)
{
    T result = 0;
    foreach (index; 0 .. N)
        result += v1[index] * v2[index];
    return result;
}

unittest
{
    {
        ulong[9] matrix = [ 
            1, 0, 0,
            0, 1, 0,
            0, 0, 1,
        ];
        ulong[3] vec = [ 1, 2, 3, ];
        assert(vec == matmul(cast(ulong[3][3]) matrix, vec));
    }
    {
        ulong[9] matrix = [ 
            1, 2, 3,
            0, 1, 0,
            0, 0, 1,
        ];
        ulong[3] vec = [ 1, 2, 3, ];
        assert([ 14, 2, 3 ] == matmul(cast(ulong[3][3]) matrix, vec));
    }
}


void diffieHellmanMatrix()
{
    const ulong[9] matrix = [
        // 1, 7, 3,
        // 5, 3, 8,
        // 1, 6, 1,
        1, 6, 2,
        6, 3, 8,
        2, 8, 2
    ];
    ref const D() { return cast(ulong[3][3]) matrix; }

    // const ulong modulus = 23;
    const ulong modulus = 17;
    // const ulong[3] i1 = [ 2, 10, 12, ];
    // const ulong[3] i2 = [ 1,  5, 16, ];
    const ulong[3] i1 = [ 1, 2, 3, ];
    const ulong[3] i2 = [ 5, 3, 1, ];

    // Cheile de încredere
    auto g1 = matmul(D, i1);
    g1[] %= modulus;

    auto g2 = matmul(D, i2);
    g2[] %= modulus;
    
    // Cheia secretă comună
    auto k12 = dot(g1, i2) % modulus;
    auto k21 = dot(g2, i1) % modulus;

    writeln("k = ", k12);
    assert(k12 == k21);
}


void blom(bool shouldGenerateNumbersRandomly)
{
    // Number of users.
    const ulong n = 3;
    assert(n >= 3);
    
    // The prime number.
    const ulong p = 187;
    assert(p >= n);

    // Number of intruders.
    const ulong k = 1;
    assert(k >= 1 && k <= n - 2);

    // Since only the simplest case is considered, k is restricted to 1.
    assert(k == 1);

    static void fillArrayWithUniqueRandomNumbersModulo(ulong[] array, ulong modulus)
    {
        import std.algorithm : canFind;
        foreach (i; 0 .. array.length)
        {
            ulong randomNumber;
            do
            {
                randomNumber = uniform!("[)", ulong)(0, modulus);
            }
            while (array[0 .. i].canFind(randomNumber));
            array[i] = randomNumber;
        }
    }

    // The random numbers generated for each of the users.
    const ulong[] randomNums = 
    (){
        if (!shouldGenerateNumbersRandomly)
        {
            return [ cast(ulong) 29, 53, 17, ];
        }
        else
        {
            auto result = new ulong[](n * k);
            fillArrayWithUniqueRandomNumbersModulo(result, p);
            return result;
        }
    }();
    assert(randomNums.length == k * n);

    // The three coefficients a, b, c.
    const ulong[3] f_coefficients = 
    (){
        ulong[3] result;
        if (!shouldGenerateNumbersRandomly)
        {
            result = [ 3, 19, 23, ];
        }
        else
        {
            fillArrayWithUniqueRandomNumbersModulo(result[], p);
        }
        return result;
    }();

    // Aliases to follow the algorithm by the spec.
    auto a() { return f_coefficients[0]; }
    auto b() { return f_coefficients[1]; }
    auto c() { return f_coefficients[2]; }
    
    // g(x) = f(x, r_u)
    // Coefficients sent to each user.
    // Contains n*k entries, k entries for each user's random number.
    const ulong[2][] gs_coefficients = // g(x) = f(x, r_1)
    (){
        auto result = new ulong[2][](n * k);
        foreach (index, randomNumber; randomNums)
        {
            ref ulong[2] outputSlice() { return result[index]; }

            // The constant term.
            outputSlice[0] += a;
            outputSlice[0] += b * randomNumber;

            // The linear term.
            outputSlice[1] += b;
            outputSlice[1] += c * randomNumber;

            outputSlice[] %= p;
        }
        return result;
    }();
    assert(gs_coefficients.length == n * k);


    // Evaluates a given g(x).
    // g(r_2) = f(r_2, r_1) 
    auto calculatePrivateKey(ulong[2] g_coefficients, ulong otherNumber)
    {
        // a + b(x + y) + cxy = a + by + (b + cy) x
        // [a + by] [b + cy] x
        auto result = g_coefficients[0] // a + by
            + otherNumber * g_coefficients[1]; // x(b + cy)
        return result % p;
    }

    // k is not implemented (I don't know what it does in the algorithm).
    ulong[2] g_coefficientsAt(ulong userIndex)
    {
        return gs_coefficients[userIndex * k];
    }

    // Check if all pairs matched
    foreach (ulong[2] indexPair; uniqueIndexPairs(3))
    {
        ulong calculate(size_t i, size_t j)
        {
            return calculatePrivateKey(g_coefficientsAt(i), randomNums[j]);
        }
        const ulong k_ab = calculate(indexPair[0], indexPair[1]);
        const ulong k_ba = calculate(indexPair[1], indexPair[0]);

        writefln("Session key k between user %d and %d is %d", indexPair[0], indexPair[1], k_ab);
        assert(k_ab == k_ba);
    }
}


auto uniqueIndexPairs(size_t upToIndexExclusive)
{
    static struct UniqueIndexPairs
    {
        size_t _upToIndexInclusive;
        size_t[2] _currentIndex;
        
        size_t[2] front()
        { 
            return _currentIndex;
        }

        bool empty()
        {
            return _currentIndex[0] == _upToIndexInclusive;
        }

        void popFront()
        {
            if (_currentIndex[1] == _upToIndexInclusive)
            {
                _currentIndex[0] += 1;
                _currentIndex[1] = _currentIndex[0] + 1;
            }
            else
            {
                _currentIndex[1] += 1;
            }
        }
    }

    UniqueIndexPairs result;

    assert(upToIndexExclusive >= 2);

    result._upToIndexInclusive = upToIndexExclusive - 1;
    result._currentIndex[0] = 0;
    result._currentIndex[1] = 1;

    return result;
}
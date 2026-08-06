using System;
using System.Security.Cryptography;
using System.Text;

public static class PasswordHelper
{
    private const int Pbkdf2Iterations = 100000;
    private const int SaltSize = 16;
    private const int HashSize = 32;
    private const string Pbkdf2Prefix = "pbkdf2:";

    public static string HashPassword(string password)
    {
        if (string.IsNullOrEmpty(password))
            throw new ArgumentException("Mot de passe vide", "password");

        byte[] salt = new byte[SaltSize];
        using (var rng = RandomNumberGenerator.Create())
        {
            rng.GetBytes(salt);
        }

        byte[] hash;
        using (var pbkdf2 = new Rfc2898DeriveBytes(password, salt, Pbkdf2Iterations))
        {
            hash = pbkdf2.GetBytes(HashSize);
        }

        return Pbkdf2Prefix + Pbkdf2Iterations + ":"
               + Convert.ToBase64String(salt) + ":"
               + Convert.ToBase64String(hash);
    }

    /// <summary>
    /// Vérifie le mot de passe (PBKDF2, ancien SHA256 Base64, ou texte clair legacy).
    /// </summary>
    public static bool VerifyPassword(string storedHash, string password, out bool needsRehash)
    {
        needsRehash = false;
        if (string.IsNullOrEmpty(storedHash) || string.IsNullOrEmpty(password))
            return false;

        if (storedHash.StartsWith(Pbkdf2Prefix, StringComparison.Ordinal))
            return VerifyPbkdf2(storedHash, password);

        if (VerifyLegacySha256(storedHash, password))
        {
            needsRehash = true;
            return true;
        }

        if (storedHash == password)
        {
            needsRehash = true;
            return true;
        }

        return false;
    }

    private static bool VerifyPbkdf2(string stored, string password)
    {
        try
        {
            string payload = stored.Substring(Pbkdf2Prefix.Length);
            string[] parts = payload.Split(':');
            if (parts.Length != 3)
                return false;

            int iterations;
            if (!int.TryParse(parts[0], out iterations) || iterations < 1000)
                return false;

            byte[] salt = Convert.FromBase64String(parts[1]);
            byte[] expected = Convert.FromBase64String(parts[2]);

            byte[] actual;
            using (var pbkdf2 = new Rfc2898DeriveBytes(password, salt, iterations))
            {
                actual = pbkdf2.GetBytes(expected.Length);
            }

            return FixedTimeEquals(actual, expected);
        }
        catch
        {
            return false;
        }
    }

    private static bool VerifyLegacySha256(string storedHash, string password)
    {
        try
        {
            using (SHA256 sha256 = SHA256.Create())
            {
                byte[] hashedBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(password));
                string computed = Convert.ToBase64String(hashedBytes);
                return FixedTimeEquals(Encoding.UTF8.GetBytes(computed), Encoding.UTF8.GetBytes(storedHash));
            }
        }
        catch
        {
            return false;
        }
    }

    private static bool FixedTimeEquals(byte[] a, byte[] b)
    {
        if (a == null || b == null || a.Length != b.Length)
            return false;

        int diff = 0;
        for (int i = 0; i < a.Length; i++)
            diff |= a[i] ^ b[i];
        return diff == 0;
    }
}

using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace Connekta.Shared.Helpers
{
    public static class SecurityHelper
    {
        private static readonly string key = "2Co_NN3_kT4%QeRuI=098_ASDFGghjkl123&%MNBVzxcvblkj5678KJHGfd&_asdfGHJpoiUYTRqwe=#$%45609812olikujyhtgXCVBNrfedwsAQmjuNHYbgtVFRcdeXSWzaq";

        public static string Encrypt(string text)
        {
            if (string.IsNullOrEmpty(text)) return text;
            try
            {
                byte[] encryptedBytes;
                byte[] utfText = Encoding.UTF8.GetBytes(text);
                byte[] utfKey = Encoding.UTF8.GetBytes(key);
                using (var sha256 = SHA256.Create())
                {
                    utfKey = sha256.ComputeHash(utfKey);
                }
                byte[] saltBytes = new byte[] { 2, 1, 7, 3, 6, 4, 8, 5 };

                using (MemoryStream ms = new MemoryStream())
                {
                    using (Aes aes = Aes.Create())
                    {
                        aes.KeySize = 256;
                        aes.BlockSize = 128;

                        var rKey = new Rfc2898DeriveBytes(utfKey, saltBytes, 1000, HashAlgorithmName.SHA1);
                        aes.Key = rKey.GetBytes(aes.KeySize / 8);
                        aes.IV = rKey.GetBytes(aes.BlockSize / 8);
                        aes.Mode = CipherMode.CBC;

                        using (var cs = new CryptoStream(ms, aes.CreateEncryptor(), CryptoStreamMode.Write))
                        {
                            cs.Write(utfText, 0, utfText.Length);
                            cs.Close();
                        }
                        encryptedBytes = ms.ToArray();
                    }
                }
                return Convert.ToBase64String(encryptedBytes);
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
        }

        public static string Decrypt(string text)
        {
            if (string.IsNullOrEmpty(text)) return text;
            try
            {
                byte[] decryptedBytes = Convert.FromBase64String(text);
                byte[] utfKey = Encoding.UTF8.GetBytes(key);
                using (var sha256 = SHA256.Create())
                {
                    utfKey = sha256.ComputeHash(utfKey);
                }
                byte[] saltBytes = new byte[] { 2, 1, 7, 3, 6, 4, 8, 5 };

                using (MemoryStream ms = new MemoryStream())
                {
                    using (Aes aes = Aes.Create())
                    {
                        aes.KeySize = 256;
                        aes.BlockSize = 128;

                        var rKey = new Rfc2898DeriveBytes(utfKey, saltBytes, 1000, HashAlgorithmName.SHA1);
                        aes.Key = rKey.GetBytes(aes.KeySize / 8);
                        aes.IV = rKey.GetBytes(aes.BlockSize / 8);
                        aes.Mode = CipherMode.CBC;

                        using (var cs = new CryptoStream(ms, aes.CreateDecryptor(), CryptoStreamMode.Write))
                        {
                            cs.Write(decryptedBytes, 0, decryptedBytes.Length);
                            cs.Close();
                        }
                        decryptedBytes = ms.ToArray();
                    }
                }
                return Encoding.UTF8.GetString(decryptedBytes);
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
        }
    }
}

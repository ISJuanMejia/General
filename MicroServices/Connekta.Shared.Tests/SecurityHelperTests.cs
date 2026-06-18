using Connekta.Shared.Helpers;
using Xunit;

namespace Connekta.Shared.Tests
{
    public class SecurityHelperTests
    {
        [Fact]
        public void Encrypt_And_Decrypt_Should_Return_Original_Text()
        {
            // Arrange
            string originalText = "Hello Connekta!";

            // Act
            string encrypted = SecurityHelper.Encrypt(originalText);
            string decrypted = SecurityHelper.Decrypt(encrypted);

            // Assert
            Assert.Equal(originalText, decrypted);
        }

        [Fact]
        public void Decrypt_With_Invalid_Base64_Should_Return_Error_Message()
        {
            // Arrange
            string invalidBase64 = "not-a-base64";

            // Act
            string result = SecurityHelper.Decrypt(invalidBase64);

            // Assert
            Assert.Contains("The input is not a valid Base-64 string", result);
        }
    }
}

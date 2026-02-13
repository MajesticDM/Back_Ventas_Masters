using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace API.MMms.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class TokenController : ControllerBase
    {
        private readonly IConfiguration _configuration;
        private readonly ISecurity _security;
        public TokenController(IConfiguration configuration, ISecurity security)
        {
            _configuration = configuration;
            _security = security;
        }
        [HttpPost]
        public async Task<IActionResult> Authentication(Security login)
        {
            var users = await _security.GetLoginByCredential(login);
            var token = "No encontrado";
            if (users != null)
            {
                token = GenerateToken();
                return Ok(new { token });
            }
            return Ok(new { token });
        }
        private string GenerateToken()
        {
            //Header
            var SymmetricSecurityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_configuration["Authentication:SecretKey"]));

            var SigningCredentials = new SigningCredentials(SymmetricSecurityKey, SecurityAlgorithms.HmacSha256);

            var header = new JwtHeader(SigningCredentials);

            //Claims
            var claims = new[]
            {
                new Claim(ClaimTypes.Email, "sadasdasd"),
                new Claim(ClaimTypes.Email, "sadasdasd"),
                new Claim(ClaimTypes.Email, "sadasdasd"),
            };

            //Payload
            var payload = new JwtPayload
            (
                _configuration["Authentication:Issuer"],
                _configuration["Authentication:Audience"],
                claims,
                DateTime.Now,
                DateTime.UtcNow.AddMinutes(10)
            );

            //Generate token
            var token = new JwtSecurityToken(header, payload);

            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }
}

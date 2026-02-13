using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.EntityFrameworkCore;

namespace INFRA.MMms.Repository
{
    public class SecurityRepo : ISecurity
    {
        private readonly MotoMastersDbContext _context;
        public SecurityRepo(MotoMastersDbContext context) {
            _context = context;
        }

        public async Task<Usuario> GetLoginByCredential(Security login)
        {
            Usuario users = await _context.Usuario.FirstOrDefaultAsync(x => x.Usuario1 == login.userName && x.Contraseña == login.password && x.Estados);
            return users;
        }
    }
}

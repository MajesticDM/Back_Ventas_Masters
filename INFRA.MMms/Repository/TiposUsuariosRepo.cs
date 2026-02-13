using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.EntityFrameworkCore;

namespace INFRA.MMms.Repository
{
    public class UsersTypeRepo : IUsersType
    {
        private readonly MotoMastersDbContext _context;
        public UsersTypeRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<UsuariosTipo>> GetUsersType()
        {
            var MMD = await _context.UsuariosTipo.ToListAsync();
            return MMD;
        }

        public async Task<UsuariosTipo> GetxId(int Id)
        {
            var MMD = await _context.UsuariosTipo.FirstOrDefaultAsync(x => x.UsuarioTipoId == Id);
            return MMD;
        }

        public async Task Post(UsuariosTipo MMD)
        {
            _context.Add(MMD);
            await _context.SaveChangesAsync();
        }

        public async Task<bool> Update(UsuariosTipo MMD)
        {
            var dat = await GetxId((int)MMD.UsuarioTipoId);

            dat.UsuarioTipo = MMD.UsuarioTipo;
            dat.Estados = MMD.Estados;

            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }

        public async Task<bool> Delete(int Id)
        {
            var Delete = await GetxId(Id);
            _context.UsuariosTipo.Remove(Delete);

            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }
    }
}

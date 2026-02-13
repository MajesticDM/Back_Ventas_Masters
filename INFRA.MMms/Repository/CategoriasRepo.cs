using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.EntityFrameworkCore;

namespace INFRA.MMms.Repository
{
    public class CategoriaRepo : ICategories
    {
        private readonly MotoMastersDbContext _context;
        public CategoriaRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Categoria>> GetCategories()
        {
            var MMD = await _context.Categoria.ToListAsync();
            return MMD;
        }

        public async Task<Categoria> GetxId(int Id)
        {
            var MMD = await _context.Categoria.FirstOrDefaultAsync(x => x.CategoriaId == Id);
            return MMD;
        }

        public async Task Post(Categoria MMD)
        {
            _context.Add(MMD);
            await _context.SaveChangesAsync();
        }

        public async Task<bool> Update(Categoria MMD)
        {
            var dat = await GetxId((int)MMD.CategoriaId);

            dat.Categoria1 = MMD.Categoria1;
            dat.Estados = MMD.Estados;


            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }

        public async Task<bool> Delete(int Id)
        {
            var Delete = await GetxId(Id);
            _context.Categoria.Remove(Delete);

            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }
    }
}

using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.EntityFrameworkCore;

namespace INFRA.MMms.Repository
{
    public class ActivosRepo : IActivos
    {
        private readonly MotoMastersDbContext _context;
        public ActivosRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Activo>> GetActivos()
        {
            var MMD = await _context.Activos.ToListAsync();
            return MMD;
        }

        public async Task<Activo> GetxId(int Id)
        {
            var MMD = await _context.Activos.FirstOrDefaultAsync(x => x.IdActivo == Id);
            return MMD;
        }

        public async Task Post(Activo MMD)
        {
            _context.Add(MMD);
            await _context.SaveChangesAsync();
        }

        public async Task<bool> Update(Activo MMD)
        {
            var dat = await GetxId((int)MMD.IdActivo);

            dat.Activo1 = MMD.Activo1;
            dat.CostoXUnidad = MMD.CostoXUnidad;
            dat.Quantity = MMD.Quantity;
            dat.Estados = MMD.Estados;

            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }

    }
}

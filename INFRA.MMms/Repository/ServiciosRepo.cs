using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.EntityFrameworkCore;

namespace INFRA.MMms.Repository
{
    public class ServicesRepo : IServices
    {
        private readonly MotoMastersDbContext _context;
        public ServicesRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Servicio>> GetServices()
        {
            var MMD = await _context.Servicio.ToListAsync();
            return MMD;
        }

        public async Task<Servicio> GetxId(int Id)
        {
            var MMD = await _context.Servicio.FirstOrDefaultAsync(x => x.ServicioId == Id);
            return MMD;
        }

        public async Task Post(Servicio MMD)
        {
            _context.Add(MMD);
            await _context.SaveChangesAsync();
        }

        public async Task<bool> Update(Servicio MMD)
        {
            var dat = await GetxId((int)MMD.ServicioId);

            dat.Servicio1 = MMD.Servicio1;
            dat.Descripcion = MMD.Descripcion;
            dat.CostoRegular = MMD.CostoRegular;
            dat.Estados = MMD.Estados;
            
            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }

        public async Task<bool> Delete(int Id)
        {
            var Delete = await GetxId(Id);
            _context.Servicio.Remove(Delete);

            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }
    }
}

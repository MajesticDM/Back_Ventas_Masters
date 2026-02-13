using Microsoft.EntityFrameworkCore;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;

namespace INFRA.MMms.Repository
{
    public class ApptsStatusRepo : IApptsStatus
    {
        private readonly MotoMastersDbContext _context;
        public ApptsStatusRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<CitasEstado>> GetApptsStatus()
        {
            var MMD = await _context.CitasEstado.ToListAsync();
            return MMD;
        }

        public async Task<CitasEstado> GetxId(int Id)
        {
            var MMD = await _context.CitasEstado.FirstOrDefaultAsync(x => x.EstadosId == Id);
            return MMD;
        }

        public async Task Post(CitasEstado MMD)
        {
            _context.Add(MMD);
            await _context.SaveChangesAsync();
        }

        public async Task<bool> Update(CitasEstado MMD)
        {
            var dat = await GetxId((int)MMD.EstadosId);

            dat.CitasEstados = MMD.CitasEstados;


            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }

        public async Task<bool> Delete(int Id)
        {
            var Delete = await GetxId(Id);
            _context.CitasEstado.Remove(Delete);

            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }
    }
}

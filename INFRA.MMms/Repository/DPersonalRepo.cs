using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.EntityFrameworkCore;

namespace INFRA.MMms.Repository
{
    public class PDataRepo : IPData
    {
        private readonly MotoMastersDbContext _context;
        public PDataRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<DatosPersonale>> GetPData()
        {
            var MMD = await _context.DatosPersonale.ToListAsync();
            return MMD;
        }

        public async Task<DatosPersonale> GetxId(int Id)
        {
            var MMD = await _context.DatosPersonale.FirstOrDefaultAsync(x => x.DatosPersonalesId == Id);
            return MMD;
        }

        public async Task Post(DatosPersonale MMD)
        {
            _context.Add(MMD);
            await _context.SaveChangesAsync();
        }

        public async Task<bool> Update(DatosPersonale MMD)
        {
            var dat = await GetxId((int)MMD.DatosPersonalesId);

            dat.Nombres = MMD.Nombres;
            dat.Apellidos = MMD.Apellidos;
            dat.NumeroTelefono = MMD.NumeroTelefono;
            dat.Email = MMD.Email;
            dat.Foto= MMD.Foto;
            dat.Estados = MMD.Estados;
            
            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }

        public async Task<bool> Delete(int Id)
        {
            var Delete = await GetxId(Id);
            _context.DatosPersonale.Remove(Delete);

            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }
    }
}

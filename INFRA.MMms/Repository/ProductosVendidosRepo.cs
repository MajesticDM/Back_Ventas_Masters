using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.EntityFrameworkCore;

namespace INFRA.MMms.Repository
{
    public class SoldProductsRepo : ISoldProducts
    {
        private readonly MotoMastersDbContext _context;
        public SoldProductsRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<VendidoProducto>> GetSoldProducts()
        {
            var MMD = await _context.VendidoProducto.ToListAsync();
            return MMD;
        }

        public async Task<VendidoProducto> GetxId(int Id)
        {
            var MMD = await _context.VendidoProducto.FirstOrDefaultAsync(x => x.IdVendidoProduct == Id);
            return MMD;
        }

        public async Task Post(VendidoProducto MMD)
        {
            _context.Add(MMD);
            await _context.SaveChangesAsync();
        }

        public async Task<bool> Update(VendidoProducto MMD)
        {
            var dat = await GetxId((int)MMD.IdVendidoProduct);

            //dat.IdxServicioDados = MMD.IdxServicioDados;
            dat.IdxProducto = MMD.IdxProducto;
            dat.Quantity = MMD.Quantity;
            dat.TotalCost = MMD.TotalCost;
            
            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }

        public async Task<bool> Delete(int Id)
        {
            var Delete = await GetxId(Id);
            _context.VendidoProducto.Remove(Delete);

            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }
    }
}

using CORE.MMms.Entidades;

namespace CORE.MMms.Interfaces
{
    public interface ISoldProducts
    {
        Task<IEnumerable<VendidoProducto>> GetSoldProducts();
        Task<VendidoProducto> GetxId(int Id);
        Task Post(VendidoProducto MMD);
        Task<bool> Update(VendidoProducto MMD);
        Task<bool> Delete(int Id);
    }
}

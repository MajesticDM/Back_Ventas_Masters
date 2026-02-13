using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IProducts
    {
        Task<IEnumerable<Producto>> GetProducts();
        DataSet GetxId(int Id);
        DataSet Post(ProductoDTOs MMD);
        DataSet Update(ProductoDTOs MMD);
        DataTable Delete(int Id);
        DataSet SelectProductos();
    }
}

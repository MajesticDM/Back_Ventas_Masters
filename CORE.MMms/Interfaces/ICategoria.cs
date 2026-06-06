using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface ICategories
    {
        Task<IEnumerable<Categoria>> GetCategories();
        Task<Categoria> GetxId(int Id);
        Task Post(Categoria MMD);
        Task<bool> Update(Categoria MMD);
        Task<bool> Delete(int Id);
        Task<DataTable> CargarCategorias();
    }
}

using CORE.MMms.Entidades;

namespace CORE.MMms.Interfaces
{
    public interface ICategories
    {
        Task<IEnumerable<Categoria>> GetCategories();
        Task<Categoria> GetxId(int Id);
        Task Post(Categoria MMD);
        Task<bool> Update(Categoria MMD);
        Task<bool> Delete(int Id);
    }
}

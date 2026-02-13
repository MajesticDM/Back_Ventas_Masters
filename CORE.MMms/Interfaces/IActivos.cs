using CORE.MMms.Entidades;

namespace CORE.MMms.Interfaces
{
    public interface IActivos
    {
        Task<IEnumerable<Activo>> GetActivos();
        Task<Activo> GetxId(int Id);
        Task Post(Activo MMD);
        Task<bool> Update(Activo MMD);
    }
}

using CORE.MMms.Entidades;

namespace CORE.MMms.Interfaces
{
    public interface IServices
    {
        Task<IEnumerable<Servicio>> GetServices();
        Task<Servicio> GetxId(int Id);
        Task Post(Servicio MMD);
        Task<bool> Update(Servicio MMD);
        Task<bool> Delete(int Id);
    }
}

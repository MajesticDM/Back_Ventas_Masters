using CORE.MMms.Entidades;

namespace CORE.MMms.Interfaces
{
    public interface IApptsStatus
    {
        Task<IEnumerable<CitasEstado>> GetApptsStatus();
        Task<CitasEstado> GetxId(int Id);
        Task Post(CitasEstado MMD);
        Task<bool> Update(CitasEstado MMD);
        Task<bool> Delete(int Id);
    }
}

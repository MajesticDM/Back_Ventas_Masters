using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IAppts
    {
        Task<IEnumerable<Cita>> GetAppts();
        Task<Cita> GetxId(int Id);
        Task Post(Cita MMD);
        Task<bool> Update(Cita MMD);
        Task<bool> Delete(int Id);
        DataSet SelectInfoDashboard();
        citaInformacion mostrarInformacionCitas();
        Task<bool> AtenderCita(int id);
    }
}

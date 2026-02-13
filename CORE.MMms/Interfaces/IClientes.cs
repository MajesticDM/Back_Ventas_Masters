using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IClients
    {
        Task<DataTable> GetClients();
        Task<DataTable> GetxId(int Id);
        Task Post(ClienteDTOs Clients);
        Task<bool> Update(ClienteDTOs Clients);
        Task<bool> Delete(int Id);
        Task<IEnumerable<ClientesConActividad>> getClientesConActividad();
        DataSet ConsultaFiscal(string accion);
        DataSet ConsultaFiscalTodo();
    }
}

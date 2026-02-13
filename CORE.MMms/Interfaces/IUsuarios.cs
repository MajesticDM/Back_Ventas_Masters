using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IUsers
    {
        Task<IEnumerable<Usuario>> GetUsers();
        Task<Usuario> GetxId(int Id);
        Task Post(Usuario MMD);
        Task<bool> Update(Usuario MMD);
        Task<bool> Delete(int Id);
        void guardarRuta(int personalDataId, string ruta);
        DataTable AccionesUsuarios(DatosAccionUsuarios datos);

    }
}

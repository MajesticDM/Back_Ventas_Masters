using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IProveedores
    {
        DataTable Mostrar();
        DataTable Actualizar(ProveedorDto dto);
        DataTable Guardar(ProveedorDto dto);
    }   
}

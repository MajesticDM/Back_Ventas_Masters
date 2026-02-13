using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IPerfiles
    {
        DataTable SelectPerfiles();
        DataTable Post(perfilesDto MMD);
        DataTable Update(perfilesDto MMD);
    }
}

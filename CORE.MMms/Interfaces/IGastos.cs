using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IGastos
    {
        DataTable SelectGastos();
        DataTable Post(GastoDto MMD);
        DataTable Update(GastoDto MMD);
    }
}

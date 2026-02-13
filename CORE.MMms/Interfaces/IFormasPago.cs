using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IFormasPago
    {
        DataSet GetFormasPago();
        DataSet Post(FormasPagoDto MMD);
        DataSet Update(FormasPagoDto MMD);
    }
}

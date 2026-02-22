using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface ICaja
    {
        DataTable getTipoMovimientos();
        DataSet getVerificarCaja(int id_usuario, int id_caja);
        bool getEstadoCaja(decimal Id);
        Task<bool> realizarMovimiento(List<RealizarMovimientosDTO> dto);
        void abrirCaja(cajaAperturaCierre dto);
        void cerrarCaja(cajaAperturaCierre dto);
        DataSet getInformeCaja(postUtilidades dto);
    }
}

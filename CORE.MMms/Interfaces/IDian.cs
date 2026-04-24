using CORE.MMms.DTOs;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IDian
    {
        // Phase 1 + 2
        DataSet GetDatosFactura(long idFactura);
        DataSet ActualizarEstado(long idFactura, string? cufe, string? estadoDian,
            string? qrDian, string? xmlDian, string? notasDian);

        // Phase 3
        DianXmlPendienteDto? GetXmlPendiente(long idFactura);
        void ActualizarTrackId(long idFactura, string trackId);

        // Report
        DataTable GetReporte(string? estadoDian, DateTime? fechaInicio, DateTime? fechaFin);
    }
}

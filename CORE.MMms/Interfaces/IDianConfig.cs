using CORE.MMms.DTOs;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IDianConfig
    {
        // Company
        DataTable GetEmpresa();
        void ActualizarEmpresa(DianEmpresaDto dto);

        // Resolutions
        DataTable GetResoluciones();
        void CrearResolucion(DianResolucionDto dto);
        void ActivarResolucion(long id, string tipo);

        // Catalog
        DataTable GetTiposIva();

        // Product DIAN fields
        DataTable GetProductoCampos(long idProducto);
        void ActualizarProductoCampos(long idProducto, DianProductoCamposDto dto);

        // Client DIAN fields
        DataTable GetClienteCampos(long idCliente);
        void ActualizarClienteCampos(long idCliente, DianClienteCamposDto dto);

        // Payment method DIAN field
        DataTable GetPagoCampo(long idPago);
        void ActualizarPagoCampo(long idPago, string? codigoMedioPago);
    }
}

using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IAbonos
    {
        DataTable getFacturas(GetAbonosDto getAbonos);
        DataTable getFacturasVenta(decimal id_factura);
        DataTable postAbonoVentas(AbonoVentaDto abonoVentaDto);
        DataTable InformeAbonosVentas(AbonosInformesDTO informe);
        DataTable InformeAbonosCompras(AbonosInformesDTO informe);
        DataTable getCompras(GetAbonosDto getAbonos);
        DataTable getAbonosCompra(decimal id_factura);
        DataTable postAbonosCompra(AbonoComprasDto abonoVentaDto);
        DataSet getAbonoVentaExcel(decimal id_factura);
    }
}

using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IReportes
    {
        // Balance financiero diario, semanal y mensual (3 filas)
        DataTable GetBalancePeriodos();

        // Resumen de ventas por producto x periodo. codigoBarras: NULL o "0" = todos
        DataTable GetVentasProductoCodigo(string codigoBarras);

        // Tendencia diaria del mes para UN producto especifico
        DataTable GetTendenciaProducto(string codigoBarras);

        // Listado real de facturas y compras de un periodo (2 result sets)
        DataSet GetListadoPeriodos(string periodo);

        // Radar de stock: velocidad de ventas y proyeccion de agotamiento
        DataTable GetRadarStock();

        // Cartera de clientes con deuda pendiente y estado de riesgo
        DataTable GetCarteraClientes();

        // Margen real por producto basado en utilidad congelada al momento de venta
        DataTable GetMargenReal();
    }
}

using CORE.MMms.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Drawing.Printing;

namespace API.MMms.Controllers
{
    //[Authorize]
    [Route("api/[controller]")]
    [ApiController]
    public class ReportesController : ControllerBase
    {
        private readonly IReportes _context;

        public ReportesController(IReportes context)
        {
            _context = context;
        }

        // GET api/Reportes/impresoras
        // Lista todas las impresoras instaladas en el servidor — usar para verificar el nombre exacto
        [HttpGet("impresoras")]
        public IActionResult GetImpresoras()
        {
            var lista = PrinterSettings.InstalledPrinters.Cast<string>().ToList();
            return Ok(lista);
        }

        // GET api/Reportes/balance
        // Balance financiero diario, semanal y mensual
        [HttpGet("balance")]
        public IActionResult GetBalancePeriodos()
        {
            return Ok(_context.GetBalancePeriodos());
        }

        // GET api/Reportes/ventas-producto?codigoBarras=7501234567890
        // GET api/Reportes/ventas-producto               <- todos los productos
        [HttpGet("ventas-producto")]
        public IActionResult GetVentasProducto([FromQuery] string? codigoBarras)
        {
            return Ok(_context.GetVentasProductoCodigo(codigoBarras));
        }

        // GET api/Reportes/tendencia-producto/7501234567890
        // Tendencia diaria del mes para un producto especifico
        [HttpGet("tendencia-producto/{codigoBarras}")]
        public IActionResult GetTendenciaProducto(string codigoBarras)
        {
            return Ok(_context.GetTendenciaProducto(codigoBarras));
        }

        // GET api/Reportes/listado/DIARIO
        // GET api/Reportes/listado/SEMANAL
        // GET api/Reportes/listado/MENSUAL
        // Retorna facturas y compras del periodo (2 tablas en el DataSet)
        [HttpGet("listado/{periodo}")]
        public IActionResult GetListadoPeriodos(string periodo)
        {
            return Ok(_context.GetListadoPeriodos(periodo));
        }

        // GET api/Reportes/radar-stock
        // Proyeccion de agotamiento por producto
        [HttpGet("radar-stock")]
        public IActionResult GetRadarStock()
        {
            return Ok(_context.GetRadarStock());
        }

        // GET api/Reportes/cartera-clientes
        // Clientes con deuda pendiente y estado de riesgo
        [HttpGet("cartera-clientes")]
        public IActionResult GetCarteraClientes()
        {
            return Ok(_context.GetCarteraClientes());
        }

        // GET api/Reportes/margen-real
        // Margen real por producto basado en utilidad congelada
        [HttpGet("margen-real")]
        public IActionResult GetMargenReal()
        {
            return Ok(_context.GetMargenReal());
        }

        // GET api/Reportes/balance-diario?fechaInicio=2026-04-08T00:00&fechaFin=2026-04-08T23:59
        // Balance diario imprimible: ventas, compras, gastos, abonos ventas, abonos compras
        [HttpGet("balance-diario")]
        public IActionResult GetBalanceDiario([FromQuery] DateTime fechaInicio, [FromQuery] DateTime fechaFin)
        {
            return Ok(_context.GetBalanceDiario(fechaInicio, fechaFin));
        }

        // GET api/Reportes/recibo-venta/21766
        // Recibo de venta: cabecera + lineas de productos para impresora POS
        [HttpGet("recibo-venta/{idFactura}")]
        public IActionResult GetReciboVenta(decimal idFactura)
        {
            return Ok(_context.GetDetalleFactura(idFactura));
        }

        // GET api/Reportes/ultimo-abono?idxFactura=21766&idxUsuario=3
        // ID del abono mas reciente para una factura (para encadenar con recibo-abono)
        [HttpGet("ultimo-abono")]
        public IActionResult GetUltimoAbono([FromQuery] decimal idxFactura, [FromQuery] decimal idxUsuario)
        {
            var id = _context.GetUltimoAbonoFactura(idxFactura, idxUsuario);
            return Ok(new { id_detalle = id });
        }

        // GET api/Reportes/recibo-abono/42
        // Comprobante de abono recibido de un cliente
        [HttpGet("recibo-abono/{idDetalle}")]
        public IActionResult GetReciboAbono(decimal idDetalle)
        {
            return Ok(_context.GetDetalleAbono(idDetalle));
        }
    }
}

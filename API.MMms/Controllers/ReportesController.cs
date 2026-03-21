using CORE.MMms.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace API.MMms.Controllers
{
    [Authorize]
    [Route("api/[controller]")]
    [ApiController]
    public class ReportesController : ControllerBase
    {
        private readonly IReportes _context;

        public ReportesController(IReportes context)
        {
            _context = context;
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
    }
}

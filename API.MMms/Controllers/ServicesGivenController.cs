using AutoMapper;
using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Data;

namespace API.MMms.Controllers
{
    [Authorize]
    [Route("api/[controller]")]
    [ApiController]
    public class ServicesGivenController : ControllerBase
    {
        private readonly IServicesGiven _context;
        private readonly IMapper _mapper;
        private readonly IServiceScopeFactory _scopeFactory;

        public ServicesGivenController(IServicesGiven context, IMapper mapper, IServiceScopeFactory scopeFactory)
        {
            _context = context;
            _mapper = mapper;
            _scopeFactory = scopeFactory;
        }


        [HttpGet]
        public async Task<IActionResult> Get()
        {
            var MMDS = await _context.GetServicesGiven();
            return Ok(MMDS);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int Id)
        {
            var UWU = await _context.GetxId(Id);
            if (UWU == null)
            {
                return Ok(UWU);
            }
            else
            {
                var OWO = _mapper.Map<ServiciosDadoDTOs>(UWU);
                return Ok(OWO);
            }
        }

        [HttpPost]
        public async Task<IActionResult> Save(ServiciosDadoDTOs dTOs)
        {
            var UWU = _mapper.Map<ServiciosDado>(dTOs);
            await _context.Post(UWU);
            return Ok(UWU);
        }

        [HttpPost("CrearFactua")]
        public async Task<IActionResult> Save(Venta venta)
        {
            string idFactura = _context.crearFacturaServiciosProductos(venta);

            if (decimal.TryParse(idFactura, out decimal idDec))
                _ = Task.Run(() =>
                {
                    using var scope = _scopeFactory.CreateScope();
                    var print = scope.ServiceProvider.GetRequiredService<IPrintService>();
                    print.ImprimirFactura(idDec);
                });

            return Ok(new { id_factura = idFactura });
        }

        [HttpPut("ActualizarFactura/{Id}/{estado}")]
        public async Task<IActionResult> Actualizar(int Id, bool estado)
        {
           bool respuesta = await _context.Update(Id, estado);
            return Ok(respuesta);
        }

        [HttpGet("ImprimirFactura/{id}")]
        public IActionResult ImprimirFactura(string id)
        {
            if (!decimal.TryParse(id, out decimal idDec))
                return BadRequest("id inválido");

            _ = Task.Run(() =>
            {
                using var scope = _scopeFactory.CreateScope();
                var print = scope.ServiceProvider.GetRequiredService<IPrintService>();
                print.ImprimirFactura(idDec);
            });

            return Ok();
        }

        [HttpPost("CargarFacturas/{todas}/{cliente}/{usuario}/{fechaInicial}/{fechaFinal}/")]
        public async Task<IActionResult> cargarFacturas(bool todas, decimal cliente, decimal usuario, string fechaInicial, string fechaFinal)
        {
            DataSet resultados = new DataSet();

            resultados = _context.SelectFacturas(todas, cliente, usuario, fechaInicial, fechaFinal);
            return Ok(resultados);
        }

        [HttpPost("CargarCompras/{todas}/{proveedor}/{usuario}/{fechaInicial}/{fechaFinal}/")]
        public async Task<IActionResult> cargarCompras(bool todas, decimal proveedor, decimal usuario, string fechaInicial, string fechaFinal)
        {
            DataSet resultados = new DataSet();

            resultados = _context.SelectCompras(todas, proveedor, usuario, fechaInicial, fechaFinal);
            return Ok(resultados);
        }

        [HttpPost("CargarFacturasPaginado/{todas}/{cliente}/{usuario}/{fechaInicial}/{fechaFinal}/{pagina}/{registrosPorPagina}")]
        public IActionResult CargarFacturasPaginado(bool todas, decimal cliente, decimal usuario, string fechaInicial, string fechaFinal, int pagina, int registrosPorPagina)
        {
            DataSet resultados = _context.SelectFacturasPaginado(todas, cliente, usuario, fechaInicial, fechaFinal, pagina, registrosPorPagina);
            return Ok(resultados);
        }

        [HttpPost("CargarComprasPaginado/{todas}/{proveedor}/{usuario}/{fechaInicial}/{fechaFinal}/{pagina}/{registrosPorPagina}")]
        public IActionResult CargarComprasPaginado(bool todas, decimal proveedor, decimal usuario, string fechaInicial, string fechaFinal, int pagina, int registrosPorPagina)
        {
            DataSet resultados = _context.SelectComprasPaginado(todas, proveedor, usuario, fechaInicial, fechaFinal, pagina, registrosPorPagina);
            return Ok(resultados);
        }
    }
}

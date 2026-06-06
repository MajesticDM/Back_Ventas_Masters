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
    public class AbonosController : ControllerBase
    {
        private readonly IAbonos _context;
        private readonly IMapper _mapper;
        private readonly IServiceScopeFactory _scopeFactory;

        public AbonosController(IAbonos context, IMapper mapper, IServiceScopeFactory scopeFactory)
        {
            _context = context;
            _mapper = mapper;
            _scopeFactory = scopeFactory;
        }

        #region Facturas

        [HttpPost("getFacturas")]
        public async Task<IActionResult> getFacturas([FromBody] GetAbonosDto Abonos)
        {
            var MMD = _context.getFacturas(Abonos);
            return Ok(MMD);
        }

        [HttpGet("getAbonosVenta/{id_factura}")]
        public async Task<IActionResult> getAbonosVenta(int id_factura)
        {
            var MMD = _context.getFacturasVenta(id_factura);
            return Ok(MMD);
        }


        [HttpPost("postAbonosVentas")]
        public async Task<IActionResult> postAbonosVentas([FromBody] AbonoVentaDto abonosDto)
        {
            var MMD = _context.postAbonoVentas(abonosDto);

            decimal idxFactura = abonosDto.idx_factura ?? 0;
            decimal idxUsuario = abonosDto.idx_usuario ?? 0;
            if (idxFactura > 0 && idxUsuario > 0)
                _ = Task.Run(() =>
                {
                    using var scope = _scopeFactory.CreateScope();
                    var print = scope.ServiceProvider.GetRequiredService<IPrintService>();
                    print.ImprimirAbono(idxFactura, idxUsuario);
                });

            return Ok(MMD);
        }

        [HttpPost("InformeAbonosVentas")]
        public async Task<IActionResult> InformeAbonosVentas([FromBody] AbonosInformesDTO abonosDto)
        {
            var MMD = _context.InformeAbonosVentas(abonosDto);
            return Ok(MMD);
        }

        [HttpGet("abonoVentaExcel/{id_factura}")]
        public async Task<IActionResult> GetAbonoVentaExcel(decimal id_factura)
        {
            var MMD = _context.getAbonoVentaExcel(id_factura);
            return Ok(MMD);
        }


        #endregion

        #region Compras

        [HttpPost("getCompras")]
        public async Task<IActionResult> getCompras([FromBody] GetAbonosDto Abonos)
        {
            var MMD = _context.getCompras(Abonos);
            return Ok(MMD);
        }

        [HttpGet("getAbonosCompra/{id_factura}")]
        public async Task<IActionResult> getAbonosCompra(int id_factura)
        {
            var MMD = _context.getAbonosCompra(id_factura);
            return Ok(MMD);
        }


        [HttpPost("postAbonosCompras")]
        public async Task<IActionResult> postAbonosCompra([FromBody] AbonoComprasDto abonosDto)
        {
            var MMD = _context.postAbonosCompra(abonosDto);

            decimal idxCompra  = abonosDto.idx_compra  ?? 0;
            decimal idxUsuario = abonosDto.idx_usuario ?? 0;
            if (idxCompra > 0 && idxUsuario > 0)
                _ = Task.Run(() =>
                {
                    using var scope = _scopeFactory.CreateScope();
                    var print = scope.ServiceProvider.GetRequiredService<IPrintService>();
                    print.ImprimirAbonoCompra(idxCompra, idxUsuario);
                });

            return Ok(MMD);
        }

        [HttpPost("InformeAbonosCompras")]
        public async Task<IActionResult> InformeAbonosCompras([FromBody] AbonosInformesDTO abonosDto)
        {
            var MMD = _context.InformeAbonosCompras(abonosDto);
            return Ok(MMD);
        }
        #endregion
    }
}

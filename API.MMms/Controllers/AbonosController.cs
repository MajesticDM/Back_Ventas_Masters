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
        public AbonosController(IAbonos context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
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
            return Ok(MMD);
        }

        #endregion
    }
}

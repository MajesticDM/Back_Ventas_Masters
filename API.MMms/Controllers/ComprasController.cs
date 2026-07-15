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
    public class ComprasController : ControllerBase
    {
        private readonly ICompras _context;
        private readonly IMapper _mapper;
        public ComprasController(ICompras context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            var MMDS = await _context.GetCompras();
            var MMD = _mapper.Map<IEnumerable<CompraDTO>>(MMDS);
            return Ok(MMD);
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
                var OWO = _mapper.Map<CompraDTO>(UWU);
                return Ok(OWO);
            }
        }

        [HttpPost]
        public async Task<IActionResult> Save(CompraDTO dTOs)
        {
            var UWU = _mapper.Map<Compra>(dTOs);
            await _context.Post(UWU);
            return Ok(UWU);
        }

        [HttpPost("Comprar")]
        public async Task<IActionResult> Comprar(CompraDTO cuerpo)
            {
            var resultado = _context.generarCompra(cuerpo);
            return Ok(resultado);
        }

        [HttpGet("Compras")]
        public async Task<IActionResult> Compras()
        {
            var resultado = _context.cargarComprasParaSelect();
            return Ok(resultado);
        }

        [HttpPut("Anular/{id}")]
        public IActionResult Anular(int id)
        {
            var (ok, mensaje) = _context.AnularCompra(id);
            if (!ok)
                return BadRequest(new { message = mensaje });
            return Ok(new { message = mensaje });
        }
    }
}

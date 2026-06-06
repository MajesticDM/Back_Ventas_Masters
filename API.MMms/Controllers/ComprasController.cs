using AutoMapper;
using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Data;
using Microsoft.Extensions.DependencyInjection;

namespace API.MMms.Controllers
{
    [Authorize]
    [Route("api/[controller]")]
    [ApiController]
    public class ComprasController : ControllerBase
    {
        private readonly ICompras _context;
        private readonly IMapper _mapper;
        private readonly IServiceScopeFactory _scopeFactory;

        public ComprasController(ICompras context, IMapper mapper, IServiceScopeFactory scopeFactory)
        {
            _context = context;
            _mapper = mapper;
            _scopeFactory = scopeFactory;
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

            decimal idxUsuario = cuerpo.usuario ?? 0;
            if (idxUsuario > 0)
                _ = Task.Run(() =>
                {
                    using var scope = _scopeFactory.CreateScope();
                    var reportes = scope.ServiceProvider.GetRequiredService<IReportes>();
                    var print    = scope.ServiceProvider.GetRequiredService<IPrintService>();
                    decimal idCompra = reportes.GetUltimaCompraUsuario(idxUsuario);
                    if (idCompra > 0) print.ImprimirCompra(idCompra);
                });

            return Ok(resultado);
        }

        [HttpGet("ImprimirCompra/{id}")]
        public async Task<IActionResult> ImprimirCompra(decimal id)
        {
            decimal idDec = id;
            _ = Task.Run(() =>
            {
                using var scope = _scopeFactory.CreateScope();
                var print = scope.ServiceProvider.GetRequiredService<IPrintService>();
                print.ImprimirCompra(idDec);
            });
            return Ok();
        }

        [HttpGet("Compras")]
        public async Task<IActionResult> Compras()
        {
            var resultado = _context.cargarComprasParaSelect();
            return Ok(resultado);
        }
    }
}

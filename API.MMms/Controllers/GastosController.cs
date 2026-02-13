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
    public class GastosController : ControllerBase
    {
        private readonly IGastos _context;
        private readonly IMapper _mapper;
        
        public GastosController(IGastos context, IMapper mapper)
        {
                _context= context; 
            _mapper = mapper;
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            var MMD = _context.SelectGastos();
            return Ok(MMD);
        }

        [HttpPost]
        public async Task<IActionResult> Save(GastoDto dTOs)
        {
            var UWU = _context.Post(dTOs);
            return Ok(UWU);
        }

        [HttpPut]
        public async Task<IActionResult> Actualizar(GastoDto dTOs)
        {
            var UWU = _context.Update(dTOs);
            return Ok(UWU);
        }
    }
}

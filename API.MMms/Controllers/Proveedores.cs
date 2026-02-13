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
    public class ProveedoresController : ControllerBase
    {
        private readonly IProveedores _context;
        private readonly IMapper _mapper;
        
        public ProveedoresController(IProveedores context, IMapper mapper)
        {
                _context= context; 
            _mapper = mapper;
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            var MMD = _context.Mostrar();
            return Ok(MMD);
        }

        [HttpPost]
        public async Task<IActionResult> Save(ProveedorDto dTOs)
        {
            var UWU = _context.Guardar(dTOs);
            return Ok(UWU);
        }

        [HttpPut]
        public async Task<IActionResult> Actualizar(ProveedorDto dTOs)
        {
            var UWU = _context.Actualizar(dTOs);
            return Ok(UWU);
        }
    }
}

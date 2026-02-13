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
    public class PerfilesController : ControllerBase
    {
        private readonly IPerfiles _context;
        private readonly IMapper _mapper;
        
        public PerfilesController(IPerfiles context, IMapper mapper)
        {
                _context= context; 
            _mapper = mapper;
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            var MMD = _context.SelectPerfiles();
            return Ok(MMD);
        }

        [HttpPost]
        public async Task<IActionResult> Save(perfilesDto dTOs)
        {
            var UWU = _context.Post(dTOs);
            return Ok(UWU);
        }

        [HttpPut]
        public async Task<IActionResult> Actualizar(perfilesDto dTOs)
        {
            var UWU = _context.Update(dTOs);
            return Ok(UWU);
        }
    }
}

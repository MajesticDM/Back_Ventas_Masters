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
    public class ActivosController : ControllerBase
    {
        private readonly IActivos _context;
        private readonly IMapper _mapper;
        public ActivosController(IActivos context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            var MMDS = await _context.GetActivos();
            var MMD = _mapper.Map<IEnumerable<ActivosDTOs>>(MMDS);
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
                var OWO = _mapper.Map<ActivosDTOs>(UWU);
                return Ok(OWO);
            }
        }

        [HttpPost]
        public async Task<IActionResult> Save(ActivosDTOs dTOs)
        {
            var UWU = _mapper.Map<Activo>(dTOs);
            await _context.Post(UWU);
            return Ok(UWU);
        }

        [HttpPut]
        public async Task<IActionResult> Actualizar(int Id, ActivosDTOs OWO)
        {
            try
            {
                var UWU = _mapper.Map<Activo>(OWO);
                await _context.Update(UWU);
                return Ok(UWU);
            }
            catch (Exception ex)
            {
                throw;
            }
            
        }

    }
}

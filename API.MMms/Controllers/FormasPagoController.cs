using AutoMapper;
using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace API.MMms.Controllers

{
    [Authorize]
    [Route("api/[controller]")]
    [ApiController]
    public class FormasPagoController : ControllerBase
    {
        private readonly IFormasPago _context;
        private readonly IMapper _mapper;
        public FormasPagoController(IFormasPago context, IMapper mapper)
        {
                _context= context; 
            _mapper = mapper;
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            return Ok(_context.GetFormasPago());
        }


        [HttpPost]
        public async Task<IActionResult> Save(FormasPagoDto dTOs)
        {
            return Ok(_context.Post(dTOs));
        }

        [HttpPut]
        public async Task<IActionResult> Actualizar(FormasPagoDto OWO)
        {
            return Ok(_context.Update(OWO));
        }
    }
}

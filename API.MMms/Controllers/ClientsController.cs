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
    public class ClientsController : ControllerBase
    {
        private readonly IClients _context;
        private readonly IMapper _mapper;
        public ClientsController(IClients context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            var Clients = await _context.GetClients();
            var Client = _mapper.Map<IEnumerable<ClienteDTOs>>(Clients);
            return Ok(Client);
        }

        [HttpGet("ClientesActividad")]
        public async Task<IActionResult> GetClientes()
        {
            var Clients = await _context.GetClients();
            return Ok(Clients);
        }

        [HttpGet("display")]
        public async Task<IActionResult> display()
        {
            var Clients = await _context.getClientesConActividad();
            return Ok(Clients);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int Id)
        {
            var UWU = await _context.GetxId(Id);
            return Ok(UWU);

        }

        [HttpPost]
        public async Task<IActionResult> Save(ClienteDTOs dTOs)
        {
            await _context.Post(dTOs);
            return Ok();
        }

        [HttpPut]
        public async Task<IActionResult> Actualizar(ClienteDTOs OWO)
        {
            await _context.Update(OWO);
            return Ok();
        }

        [HttpDelete]
        public async Task<IActionResult> Eliminar(int Id)
        {
            var UWU = await _context.Delete(Id);
            return Ok(UWU);
        }

        [HttpGet("RegimenTributario")]
        public async Task<IActionResult> GetRegimenTributario()
        {
            return Ok(_context.ConsultaFiscal("RT"));
        }

        [HttpGet("ResponsabilidadFiscal/")]
        public async Task<IActionResult> GetResponsabilidadFiscal()
        {
            return Ok(_context.ConsultaFiscal("RT"));
        }

        [HttpGet("TipoIdentificacion/")]
        public async Task<IActionResult> GetTipoIdentificacion()
        {
            return Ok(_context.ConsultaFiscal("RT"));
        }

        [HttpGet("ConsultaFiscalTodo/")]
        public async Task<IActionResult> ConsultaFiscalTodo()
        {
            return Ok(_context.ConsultaFiscalTodo());
        }
    }
}

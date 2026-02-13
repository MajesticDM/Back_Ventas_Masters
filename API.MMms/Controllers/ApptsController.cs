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
    public class ApptsController : ControllerBase
    {
        private readonly IAppts _context;
        private readonly IMapper _mapper;
        public ApptsController(IAppts context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            var MMDS = await _context.GetAppts();
            var MMD = _mapper.Map<IEnumerable<CitaDTOs>>(MMDS);
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
                var OWO = _mapper.Map<CitaDTOs>(UWU);
                return Ok(OWO);
            }
        }

        [HttpPost]
        public async Task<IActionResult> Save(CitaDTOs dTOs)
        {
            var UWU = _mapper.Map<Cita>(dTOs);
            await _context.Post(UWU);
            return Ok(UWU);
        }

        [HttpPut]
        public async Task<IActionResult> Actualizar(int Id, CitaDTOs OWO)
        {
            try
            {
                var UWU = _mapper.Map<Cita>(OWO);
                await _context.Update(UWU);
                return Ok(UWU);
            }
            catch (Exception ex)
            {
                throw;
            }
            
        }

        [HttpDelete]
        public async Task<IActionResult> Eliminar(int Id)
        {
            var UWU = await _context.Delete(Id);
            return Ok(UWU);
        }

        [HttpGet("dashboard")]
        public async Task<IActionResult> getDashboardInfo()
        {
            DataSet dashboard = _context.SelectInfoDashboard();
            return Ok(dashboard);
        }

        [HttpGet("CitasInformacion")]
        public async Task<IActionResult> CitasInformacion()
        {
            citaInformacion citaInformacion = _context.mostrarInformacionCitas();
            return Ok(citaInformacion);
        }
        [HttpPost("AtenderCita/{Id}")]
        public async Task<IActionResult> AtenderCita(int Id)
        {
            try
            {
                await _context.AtenderCita(Id);
                return Ok(true);
            }
            catch (Exception ex)
            {
                throw;
            }

        }
    }
}

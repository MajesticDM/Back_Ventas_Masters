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
    public class ConfiguracionesController : ControllerBase
    {
        private readonly IConfiguraciones _context;
        private readonly IMapper _mapper;
        public ConfiguracionesController(IConfiguraciones context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        [HttpGet("Configuracion/consultar")]
        public IActionResult GetConfiguracionGeneral()
        {
            return Ok(_context.SeleccionarConfiguracionGeneral());
        }

        [HttpGet("Notificaciones/mostrar")]
        public async Task<IActionResult> consultarNotificaciones()
        {
            var notificaciones = _context.SelectConfiguracionesNotificaciones("notificaciones");
            return Ok(notificaciones);
        }

        [HttpPost("Notificaciones/crear")]
        public async Task<IActionResult> CrearNotificacion(NotificacionesConfiguracion notificaciones)
        {   
            var guardado = _context.ModificarConfiguracionNotificaciones("guardar", notificaciones.id_notificacion, notificaciones.servicio, notificaciones.periocidad, notificaciones.periocidad_inmediata, notificaciones.solo_activos, notificaciones.tipo_notificacion);
            return Ok(guardado);
        }

        [HttpGet("Notificaciones/eliminar/{id}")]
        public async Task<IActionResult> eliminarNotificacion(int id)
        {
            var notificaciones = _context.ModificarConfiguracionNotificaciones("eliminar", id, 0, null, null, null, null);
            return Ok(notificaciones);
        }

    }
}

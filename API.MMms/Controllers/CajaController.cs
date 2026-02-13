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
    public class CajaController : ControllerBase
    {
        private readonly IActivos _context;
        public CajaController(IActivos context)
        {
            _context = context;
        }

        [HttpGet("getEstadoCaja/{id}")] // [1]
        public async Task<IActionResult> getEstadoCaja(int Id)
        {
            
        }

        [HttpGet("getVerificarCaja/{id}/{id_caja}")]
        public async Task<IActionResult> getVerificarCaja(int Id, int id_caja)
        {

        }

        [HttpGet("getTipoMovimientos/")] // [2]
        public async Task<IActionResult> getTipoMovimientos()
        {

        }

        [HttpPost("postRealizarMovimiento/")]
        public async Task<IActionResult> postRealizarMovimiento(ActivosDTOs dTOs)
        {
            
        }

        [HttpPost("postCajaApertura/")]
        public async Task<IActionResult> postCajaApertura(ActivosDTOs dTOs)
        {

        }

        [HttpPost("postCajaCierre/")]
        public async Task<IActionResult> postCajaCierre(ActivosDTOs dTOs)
        {
            
        }


    }
}

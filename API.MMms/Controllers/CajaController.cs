using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Data;

namespace API.MMms.Controllers
{
    //[Authorize]
    [Route("api/[controller]")]
    [ApiController]
    public class CajaController : ControllerBase
    {
        private readonly ICaja _context;
        public CajaController(ICaja context)
        {
            _context = context;
        }

        [HttpGet("getEstadoCaja/{id}")] // [1]
        public async Task<IActionResult> getEstadoCaja(decimal id)
        {
            return Ok(_context.getEstadoCaja(id));
        }

        [HttpGet("getVerificarCaja/{id}/{id_caja}")]
        public async Task<IActionResult> getVerificarCaja(int Id, int id_caja)
        {
            return Ok(_context.getVerificarCaja(Id, id_caja));
        }

        [HttpGet("getTipoMovimientos/")] // [2]
        public async Task<IActionResult> getTipoMovimientos()
        {
            return Ok(_context.getTipoMovimientos());
        }

        [HttpPost("postRealizarMovimiento/")]
        public async Task<IActionResult> postRealizarMovimiento(List<RealizarMovimientosDTO> dTOs)
        {
            bool res = await _context.realizarMovimiento(dTOs);
            return Ok(res);
        }

        [HttpPost("postCajaApertura/")]
        public async Task<IActionResult> postCajaApertura(cajaAperturaCierre dto)
        {
            _context.abrirCaja(dto); 
            return Ok();
        }

        [HttpPost("postCajaCierre/")]
        public async Task<IActionResult> postCajaCierre(cajaAperturaCierre dto)
        {
            _context.cerrarCaja(dto);
            return Ok();
        }

        [HttpPost("postUtilidades")]
        public async Task<IActionResult> postUtilidades(postUtilidades cuerpo)
        {
            var result = _context.getInformeCaja(cuerpo);
            return Ok(result);
        }

    }
}

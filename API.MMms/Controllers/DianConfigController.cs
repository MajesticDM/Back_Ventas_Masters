using CORE.MMms.DTOs;
using CORE.MMms.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace API.MMms.Controllers
{
    [Authorize]
    [Route("api/[controller]")]
    [ApiController]
    public class DianConfigController : ControllerBase
    {
        private readonly IDianConfig _repo;

        public DianConfigController(IDianConfig repo) => _repo = repo;

        // ── Company ──────────────────────────────────────────────
        [HttpGet("Empresa")]
        public IActionResult GetEmpresa()
        {
            try   { return Ok(_repo.GetEmpresa()); }
            catch (Exception ex) { return StatusCode(500, new { error = ex.Message }); }
        }

        [HttpPut("Empresa")]
        public IActionResult ActualizarEmpresa([FromBody] DianEmpresaDto dto)
        {
            try   { _repo.ActualizarEmpresa(dto); return Ok(); }
            catch (Exception ex) { return StatusCode(500, new { error = ex.Message }); }
        }

        // ── Resolutions ──────────────────────────────────────────
        [HttpGet("Resoluciones")]
        public IActionResult GetResoluciones()
        {
            try   { return Ok(_repo.GetResoluciones()); }
            catch (Exception ex) { return StatusCode(500, new { error = ex.Message }); }
        }

        [HttpPost("Resoluciones")]
        public IActionResult CrearResolucion([FromBody] DianResolucionDto dto)
        {
            try   { _repo.CrearResolucion(dto); return Ok(); }
            catch (Exception ex) { return StatusCode(500, new { error = ex.Message }); }
        }

        [HttpPut("Resoluciones/{id}/Activar")]
        public IActionResult ActivarResolucion(long id, [FromQuery] string tipo = "FC")
        {
            try   { _repo.ActivarResolucion(id, tipo); return Ok(); }
            catch (Exception ex) { return StatusCode(500, new { error = ex.Message }); }
        }

        // ── Catalog ──────────────────────────────────────────────
        [HttpGet("TiposIva")]
        public IActionResult GetTiposIva()
        {
            try   { return Ok(_repo.GetTiposIva()); }
            catch (Exception ex) { return StatusCode(500, new { error = ex.Message }); }
        }

        // ── Product ──────────────────────────────────────────────
        [HttpGet("Producto/{id}")]
        public IActionResult GetProductoCampos(long id)
        {
            try   { return Ok(_repo.GetProductoCampos(id)); }
            catch (Exception ex) { return StatusCode(500, new { error = ex.Message }); }
        }

        [HttpPut("Producto/{id}")]
        public IActionResult ActualizarProducto(long id, [FromBody] DianProductoCamposDto dto)
        {
            try   { _repo.ActualizarProductoCampos(id, dto); return Ok(); }
            catch (Exception ex) { return StatusCode(500, new { error = ex.Message }); }
        }

        // ── Client ───────────────────────────────────────────────
        [HttpGet("Cliente/{id}")]
        public IActionResult GetClienteCampos(long id)
        {
            try   { return Ok(_repo.GetClienteCampos(id)); }
            catch (Exception ex) { return StatusCode(500, new { error = ex.Message }); }
        }

        [HttpPut("Cliente/{id}")]
        public IActionResult ActualizarCliente(long id, [FromBody] DianClienteCamposDto dto)
        {
            try   { _repo.ActualizarClienteCampos(id, dto); return Ok(); }
            catch (Exception ex) { return StatusCode(500, new { error = ex.Message }); }
        }

        // ── Payment method ────────────────────────────────────────
        [HttpGet("FormaPago/{id}")]
        public IActionResult GetFormaPago(long id)
        {
            try   { return Ok(_repo.GetPagoCampo(id)); }
            catch (Exception ex) { return StatusCode(500, new { error = ex.Message }); }
        }

        [HttpPut("FormaPago/{id}")]
        public IActionResult ActualizarFormaPago(long id, [FromBody] DianPagoCampoDto dto)
        {
            try   { _repo.ActualizarPagoCampo(id, dto.CodigoMedioPagoDian); return Ok(); }
            catch (Exception ex) { return StatusCode(500, new { error = ex.Message }); }
        }
    }
}

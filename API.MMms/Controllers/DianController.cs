using CORE.MMms.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace API.MMms.Controllers
{
    [Authorize]
    [Route("api/[controller]")]
    [ApiController]
    public class DianController : ControllerBase
    {
        private readonly IDianXmlService          _dianXmlService;
        private readonly IDianTransmissionService _transmissionService;
        private readonly IDian                    _dianRepo;

        public DianController(
            IDianXmlService dianXmlService,
            IDianTransmissionService transmissionService,
            IDian dianRepo)
        {
            _dianXmlService      = dianXmlService;
            _transmissionService = transmissionService;
            _dianRepo            = dianRepo;
        }

        /// <summary>
        /// Phases 1+2: Generates the UBL 2.1 XML, computes the CUFE, and signs with XAdES-B-BES.
        /// Persists the signed XML and CUFE to FACTURAS via SP_DIAN_ACTUALIZAR_ESTADO.
        /// The invoice remains in PENDIENTE state until Phase 3 (DIAN transmission).
        /// </summary>
        [HttpPost("GenerarXml/{idFactura}")]
        public IActionResult GenerarXml(long idFactura)
        {
            try
            {
                var result = _dianXmlService.GenerarXml(idFactura);
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return NotFound(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = ex.Message });
            }
        }

        /// <summary>
        /// Phase 3: Packages the signed XML as a ZIP, transmits it to the DIAN SOAP service,
        /// and polls for a validation result. Final state is persisted to FACTURAS.
        /// Returns: EstadoDian (VALIDADA / RECHAZADA / PENDIENTE / CONTINGENCIA), QrDian, TrackId.
        /// </summary>
        [HttpPost("EnviarFactura/{idFactura}")]
        public async Task<IActionResult> EnviarFactura(long idFactura)
        {
            try
            {
                var result = await _transmissionService.EnviarFacturaAsync(idFactura);
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return NotFound(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = ex.Message });
            }
        }

        /// <summary>
        /// Phase 3 (retry): Re-polls DIAN using the TrackId already stored in FACTURAS.
        /// Use when a previous EnviarFactura call timed out and the invoice is still PENDIENTE.
        /// </summary>
        [HttpPost("ConsultarEstado/{idFactura}")]
        public async Task<IActionResult> ConsultarEstado(long idFactura)
        {
            try
            {
                var result = await _transmissionService.ConsultarEstadoAsync(idFactura);
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return NotFound(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = ex.Message });
            }
        }

        /// <summary>
        /// Report: returns all invoices with a DIAN state, optionally filtered.
        /// </summary>
        [HttpGet("Reporte")]
        public IActionResult Reporte(
            [FromQuery] string?   estado      = null,
            [FromQuery] DateTime? fechaInicio = null,
            [FromQuery] DateTime? fechaFin    = null)
        {
            try
            {
                var dt = _dianRepo.GetReporte(estado, fechaInicio, fechaFin);
                return Ok(dt);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = ex.Message });
            }
        }

        /// <summary>
        /// Bulk send: transmits multiple signed invoices to DIAN in parallel.
        /// Body: { "ids": [1, 2, 3] }
        /// </summary>
        [HttpPost("EnviarLote")]
        public async Task<IActionResult> EnviarLote([FromBody] long[] ids)
        {
            if (ids == null || ids.Length == 0)
                return BadRequest(new { error = "Debe enviar al menos un ID de factura." });
            try
            {
                var result = await _transmissionService.EnviarLoteAsync(ids);
                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = ex.Message });
            }
        }
    }
}

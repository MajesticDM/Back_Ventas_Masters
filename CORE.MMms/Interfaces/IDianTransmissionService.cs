using CORE.MMms.DTOs;

namespace CORE.MMms.Interfaces
{
    public interface IDianTransmissionService
    {
        /// <summary>
        /// Packages the signed XML as a ZIP, sends it to the DIAN SOAP service via
        /// SendBillAsync, then polls GetStatus until a definitive response is received.
        /// Persists the final ESTADO_DIAN (VALIDADA / RECHAZADA / CONTINGENCIA / PENDIENTE)
        /// and QR URL (when valid) back to the FACTURAS row.
        /// </summary>
        Task<DianEnvioResultDto> EnviarFacturaAsync(long idFactura);

        /// <summary>
        /// Re-polls DIAN using the TRACK_ID_DIAN already stored in FACTURAS.
        /// Use this when a previous EnviarFactura call timed out during polling
        /// and the invoice is still in PENDIENTE state with a known TrackId.
        /// </summary>
        Task<DianEnvioResultDto> ConsultarEstadoAsync(long idFactura);

        /// <summary>
        /// Sends multiple invoices to DIAN in parallel. Each invoice must already have
        /// a signed XML (CUFE not null). Returns a summary with per-invoice results.
        /// </summary>
        Task<DianLoteResultDto> EnviarLoteAsync(long[] ids);
    }
}

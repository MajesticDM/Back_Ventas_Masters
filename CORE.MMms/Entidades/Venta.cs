using CORE.MMms.DTOs;

namespace CORE.MMms.Entidades
{
    public class Venta
    {
        public decimal usuario_id { get; set; }
        public decimal cliente_id { get; set; }
        public decimal costoTotal { get; set; }
        public bool consumidorFinal { get; set; }
        public decimal valoR_PAGADO { get; set; }
        public decimal idX_FORMA_PAGO { get; set; }
        public decimal idx_forma_pago_pago_inicial { get; set; }
        public bool uso_saldo_favor { get; set; }
        public List<ServicioFacturaDto> servicios { get; set; }
        public List<VendidoProductoDTOs> productos { get; set; }
    }
}

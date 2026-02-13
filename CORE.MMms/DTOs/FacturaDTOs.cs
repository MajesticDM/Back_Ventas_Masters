using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CORE.MMms.DTOs
{
    public class FacturaDTOs
    {
        public decimal IdFactura { get; set; }

        public decimal IdxCliente { get; set; }

        public decimal IdxUsuario { get; set; }

        public decimal CostoTotal { get; set; }

        public DateTime FechaVenta { get; set; }

        public bool Estado { get; set; }
    }
}

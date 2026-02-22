using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CORE.MMms.DTOs
{
    public class RealizarMovimientosDTO
    {
        public decimal IDX_DENOMINACION { get; set; }
        public decimal VALOR { get; set; }
        public decimal IDX_USUARIO { get; set; }
        public decimal IDX_GASTO { get; set; }
        public decimal IDX_TIPO_MOVIMIENTO { get; set; }
        public string DESCRIPCION { get; set; }
    }
}

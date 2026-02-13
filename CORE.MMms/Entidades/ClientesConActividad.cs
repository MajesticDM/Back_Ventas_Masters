using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CORE.MMms.Entidades
{
    public class ClientesConActividad
    {
        public decimal ClienteId { get; set; }

        public string? Nombres { get; set; }

        public string Apellidos { get; set; } = null!;

        public decimal NumeroTelefono { get; set; }

        public bool TieneVehiculo { get; set; }

        public string? PlacaVehiculo { get; set; }

        public string? ColorVehiculo { get; set; }

        public string? MarcaVehiculo { get; set; }

        public byte[]? ClienteFoto { get; set; }

        public bool? ClienteRegular { get; set; }
        public bool? bitAceptaWhatsapp { get; set; }
        public bool? bitAceptaCorreo { get; set; }
        public string? correo_electronico { get; set; }

        public DateTime? fechaUltimaVisita { get; set; }
    }
}

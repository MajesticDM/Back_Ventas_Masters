using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public partial class Cliente
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

    public virtual ICollection<Cita> Cita { get; set; } = new List<Cita>();

    public virtual ICollection<Factura> Facturas { get; set; } = new List<Factura>();
}

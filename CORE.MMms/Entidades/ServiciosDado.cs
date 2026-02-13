using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public partial class ServiciosDado
{
    public decimal ServicioDadosId { get; set; }

    public decimal IdxFactura { get; set; }

    public decimal IdxServicio { get; set; }

    public bool ClienteDejoLlaves { get; set; }

    public string? DescripcionLlaves { get; set; }

    public bool? BitVehiculoInicial { get; set; }

    public string? PlacaVehiculo { get; set; }

    public string? ColorVehiculo { get; set; }

    public string? MarcaVehiculo { get; set; }

    public double? CostoAdicional { get; set; }

    public double? TotalCost { get; set; }

    public DateTime FechaServicioDado { get; set; }

    public virtual Factura IdxFacturaNavigation { get; set; } = null!;

    public virtual Servicio IdxServicioNavigation { get; set; } = null!;
}

using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public partial class Activo
{
    public decimal IdActivo { get; set; }

    public string Activo1 { get; set; } = null!;

    public double CostoXUnidad { get; set; }

    public decimal Quantity { get; set; }

    public bool Estados { get; set; }

}

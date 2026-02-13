using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public partial class Servicio
{
    public decimal ServicioId { get; set; }

    public string Servicio1 { get; set; } = null!;

    public string Descripcion { get; set; } = null!;

    public double? CostoRegular { get; set; }

    public bool Estados { get; set; }

    public virtual ICollection<Cita> Cita { get; set; } = new List<Cita>();

    public virtual ICollection<ServiciosDado> ServiciosDados { get; set; } = new List<ServiciosDado>();
}

using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public partial class CitasEstado
{
    public decimal EstadosId { get; set; }

    public string CitasEstados { get; set; } = null!;

    public virtual ICollection<Cita> Cita { get; set; } = new List<Cita>();
}

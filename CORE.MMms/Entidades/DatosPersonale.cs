using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public partial class DatosPersonale
{
    public decimal? DatosPersonalesId { get; set; }

    public string? Nombres { get; set; } = null!;

    public string? Apellidos { get; set; } = null!;

    public decimal? NumeroTelefono { get; set; }

    public string? Email { get; set; } = null!;

    public string? Foto { get; set; }

    public bool? Estados { get; set; }

    public virtual ICollection<Usuario> Usuarios { get; set; } = new List<Usuario>();
}

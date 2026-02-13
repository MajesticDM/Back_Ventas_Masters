using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public partial class UsuariosTipo
{
    public decimal UsuarioTipoId { get; set; }

    public string UsuarioTipo { get; set; } = null!;

    public bool Estados { get; set; }

    public virtual ICollection<Usuario> Usuarios { get; set; } = new List<Usuario>();
}

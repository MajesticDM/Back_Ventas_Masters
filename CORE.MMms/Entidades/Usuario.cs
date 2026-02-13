using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public partial class Usuario
{
    public decimal UsuarioId { get; set; }

    public decimal IdxUsuarioTipo { get; set; }

    public decimal IdxDatosPersonales { get; set; }

    public string Usuario1 { get; set; } = null!;

    public string Contraseña { get; set; } = null!;

    public DateTime FechaCreacion { get; set; }

    public bool Estados { get; set; }

    public byte[]? Foto { get; set; }

    public virtual ICollection<Cita> Cita { get; set; } = new List<Cita>();

    public virtual ICollection<Factura> Facturas { get; set; } = new List<Factura>();

    public virtual DatosPersonale IdxDatosPersonalesNavigation { get; set; } = null!;

    public virtual UsuariosTipo IdxUsuarioTipoNavigation { get; set; } = null!;
}

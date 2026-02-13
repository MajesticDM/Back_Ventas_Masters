
using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public partial class Factura
{
    public decimal IdFactura { get; set; }

    public decimal IdxCliente { get; set; }

    public decimal IdxUsuario { get; set; }

    public decimal CostoTotal { get; set; }

    public DateTime FechaVenta { get; set; }

    public bool Estado { get; set; }

    public virtual Cliente IdxClienteNavigation { get; set; } = null!;

    public virtual Usuario IdxUsuarioNavigation { get; set; } = null!;

    public virtual ICollection<ServiciosDado> ServiciosDados { get; set; } = new List<ServiciosDado>();

    public virtual ICollection<VendidoProducto> VendidoProductos { get; set; } = new List<VendidoProducto>();
}

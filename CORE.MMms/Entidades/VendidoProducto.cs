using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public partial class VendidoProducto
{
    public decimal IdVendidoProduct { get; set; }

    public decimal IdxFactura { get; set; }

    public decimal? IdxProducto { get; set; }

    public decimal? Quantity { get; set; }

    public double? TotalCost { get; set; }

    public virtual Factura IdxFacturaNavigation { get; set; } = null!;

    public virtual Producto? IdxProductoNavigation { get; set; }
}

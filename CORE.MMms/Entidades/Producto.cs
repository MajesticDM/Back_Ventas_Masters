using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public partial class Producto
{
    public decimal ProductId { get; set; }

    public decimal IdxCategoria { get; set; }

    public string Producto1 { get; set; } = null!;

    public double CostoXUnidad { get; set; }

    public decimal Quantity { get; set; }

    public bool Estados { get; set; }

    public virtual Categoria IdxCategoriaNavigation { get; set; } = null!;

    public virtual ICollection<VendidoProducto> VendidoProductos { get; set; } = new List<VendidoProducto>();
}

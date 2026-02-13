using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public class ComprasDetalle
{
    public decimal IdCompraDetalle { get; set; }

    public decimal IdxCompra { get; set; }

    public decimal? IdxProducto { get; set; }

    public decimal? IdxServicio { get; set; }

    public decimal? Cantidad { get; set; }

    public decimal? Costo { get; set; }

    public string? ComentarioProducto { get; set; }

    public decimal? IdxActivo { get; set; }
}


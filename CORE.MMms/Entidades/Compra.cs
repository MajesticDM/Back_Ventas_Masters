using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public class Compra
{
    public decimal IdCompra { get; set; }

    public decimal? CostoTotal { get; set; }

    public decimal IdxUsuarioComprador { get; set; }

    public DateTime FechaCompra { get; set; }

    public string? ComentarioCompra { get; set; }
}

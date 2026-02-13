using System;
using System.Collections.Generic;

namespace CORE.MMms.Entidades;

public partial class Categoria
{
    public decimal CategoriaId { get; set; }

    public string Categoria1 { get; set; } = null!;

    public bool Estados { get; set; }

    public virtual ICollection<Producto> Productos { get; set; } = new List<Producto>();
}

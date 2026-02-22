using System;
using System.Collections.Generic;

namespace CORE.MMms.DTOs;

public class CuerpoCompraDto
{
    public bool? existente { get; set; }
    public decimal? producto { get; set; }
    public string? productoNombre { get; set; }
    public decimal? costoUnidad { get; set; }
    public decimal? costoTotal { get; set; }
    public decimal? cantidad { get; set; }

    public decimal? categoriaId { get; set; }
    public string? categoriaNombre { get; set; }

    public string? codigoProducto { get; set; }

    public decimal? tipoMedida { get; set; }
    public decimal? medidaPejase { get; set; }
    public decimal? gramajeProducto { get; set; }
    public decimal? gramajeUnidad { get; set; }
    public decimal? gramaje_total { get; set; }
}


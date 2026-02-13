using System;
using System.Collections.Generic;

namespace CORE.MMms.DTOs;

public partial class CompraDTO
{
    public decimal? usuario { get; set; }
    public decimal? formapago { get; set; }
    public decimal? proveedorId { get; set; }
    public bool credito { get; set; }
    public decimal? pagoInicial { get; set; }
    public decimal? fpagoInicial { get; set; }

    public List<CuerpoCompraDto> cuerpoCompras { get; set; }

}

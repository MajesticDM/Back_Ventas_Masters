namespace CORE.MMms.DTOs;

public class AbonoVentaDto
{
    public decimal? id_detalle { get; set; }
    public decimal? idx_factura { get; set; }
    public decimal? idx_usuario{ get; set; }
    public decimal? idx_cliente { get; set; }
    public decimal? forma_pago { get; set; }
    public decimal? valor_pagado { get; set; }
    public string? comentario { get; set; }
    public bool? pago_total { get; set; }
    public bool? pago_proveedor { get; set; }
    public decimal? compra { get; set; }
    public bool? estado { get; set; }
    public DateTime? fecha_final { get; set; }
    public DateTime? fecha_inicial { get; set; }
    public int pagina { get; set; } = 1;
    public int tamano_pagina { get; set; } = 10;
}
